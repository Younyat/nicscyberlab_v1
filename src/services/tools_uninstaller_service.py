import json
import os
import subprocess
from dataclasses import asdict
from pathlib import Path
from typing import List, Optional, Dict

from src.models.tools import InstanceTarget, ToolInstallPlan
from src.services.tools_installer_service import ToolsInstallerService


class ToolsUninstallerService:
    """
    Servicio de desinstalación de herramientas en instancias del escenario.

    Usa el mismo formato de JSON que la instalación:
      tools-installer-tmp/*_tools.json

    Para cada herramienta definida en 'tools', ejecuta el correspondiente
    uninstall.sh dentro de la instancia vía SSH.
    """

    def __init__(
        self,
        repo_root: Path,
        tools_json_dir: Optional[Path] = None,
        installers_dir: Optional[Path] = None,
        logs_dir: Optional[Path] = None,
        admin_openrc: Optional[Path] = None,
    ) -> None:
        self.repo_root = repo_root
        self.tools_json_dir = tools_json_dir or repo_root / "tools-installer-tmp"
        self.installers_dir = installers_dir or repo_root / "tools-installer" / "installers"
        self.logs_dir = logs_dir or repo_root / "tools-installer" / "logs"
        self.admin_openrc = admin_openrc or repo_root / "admin-openrc.sh"

        self.logs_dir.mkdir(parents=True, exist_ok=True)

        # Reutilizamos funciones auxiliares del instalador
        self.installer_service = ToolsInstallerService(
            repo_root=repo_root,
            tools_json_dir=self.tools_json_dir,
            installers_dir=self.installers_dir,
            logs_dir=self.logs_dir,
            admin_openrc=self.admin_openrc,
        )

    # ------------------------------------------------------------------
    # Utilidades internas (envoltorios sobre ToolsInstallerService)
    # ------------------------------------------------------------------

    def _run(self, cmd: List[str], env: Optional[Dict[str, str]] = None) -> str:
        return self.installer_service._run(cmd, env)

    def _load_openstack_env(self) -> Dict[str, str]:
        return self.installer_service._load_openstack_env()

    def _detect_ssh_key(self) -> Path:
        return self.installer_service._detect_ssh_key()

    def _openstack_get_image_name(self, env: Dict[str, str], instance_name_or_id: str) -> str:
        return self.installer_service._openstack_get_image_name(env, instance_name_or_id)

    def _guess_ssh_user(self, image_name: str):
        return self.installer_service._guess_ssh_user(image_name)

    def _probe_ssh_user(self, ssh_key: Path, ip: str, candidates: List[str]) -> str:
        return self.installer_service._probe_ssh_user(ssh_key, ip, candidates)

    # ------------------------------------------------------------------
    # Carga de planes desde JSON (misma lógica que instalación)
    # ------------------------------------------------------------------

    def _load_tool_plans(self) -> List[ToolInstallPlan]:
        plans: List[ToolInstallPlan] = []

        if not self.tools_json_dir.is_dir():
            raise FileNotFoundError(f"No existe el directorio de JSONs de tools: {self.tools_json_dir}")

        for json_file in sorted(self.tools_json_dir.glob("*_tools.json")):
            with json_file.open("r", encoding="utf-8") as f:
                raw = json.load(f)

            inst = InstanceTarget(
                id=str(raw.get("id")),
                name=str(raw.get("name")),
                type=str(raw.get("type")),
                ip_private=str(raw.get("ip_private")),
                ip_floating=raw.get("ip_floating"),
                ip=str(raw.get("ip")),
                status=str(raw.get("status")),
            )
            tools = list(raw.get("tools", []))
            plans.append(ToolInstallPlan(instance=inst, tools=tools, source_json=json_file))

        return plans

    # ------------------------------------------------------------------
    # Resolución de rutas y logs
    # ------------------------------------------------------------------

    def _uninstaller_path_for(self, tool_name: str) -> Path:
        t = tool_name.lower()
        tool_dir = self.installers_dir / t
        uninstaller = tool_dir / "uninstall.sh"
        if not uninstaller.is_file():
            raise FileNotFoundError(f"No se encontró uninstaller para '{tool_name}' en {uninstaller}")
        return uninstaller

    def _log_path_for(self, instance_name: str, tool_name: str) -> Path:
        safe_instance = instance_name.replace(" ", "_")
        safe_tool = tool_name.replace(" ", "_")
        return self.logs_dir / f"{safe_instance}_{safe_tool}_uninstall.log"

    # ------------------------------------------------------------------
    # API pública
    # ------------------------------------------------------------------

    def run_all_uninstall_plans(self) -> List[Dict]:
        """
        Ejecuta la desinstalación de todas las herramientas definidas en tools-installer-tmp.
        Devuelve una lista de resultados por plan/herramienta.
        """
        env = self._load_openstack_env()
        ssh_key = self._detect_ssh_key()
        plans = self._load_tool_plans()

        results: List[Dict] = []

        for plan in plans:
            instance = plan.instance
            ip = instance.ip
            image_name = self._openstack_get_image_name(env, instance.name)
            ssh_candidates = self._guess_ssh_user(image_name)
            ssh_user = self._probe_ssh_user(ssh_key, ip, ssh_candidates)

            for tool in plan.tools:
                uninstaller_path = self._uninstaller_path_for(tool)
                log_path = self._log_path_for(instance.name, tool)

                # 1) copiar uninstaller
                scp_cmd = [
                    "scp",
                    "-o", "StrictHostKeyChecking=no",
                    "-i", str(ssh_key),
                    str(uninstaller_path),
                    f"{ssh_user}@{ip}:/tmp/uninstall_{tool}.sh",
                ]

                try:
                    self._run(scp_cmd)
                except subprocess.CalledProcessError as e:
                    results.append({
                        "instance": asdict(instance),
                        "tool": tool,
                        "status": "scp_failed",
                        "error": e.stderr if hasattr(e, "stderr") else str(e),
                    })
                    continue

                # 2) permisos remotos
                chmod_cmd = [
                    "ssh",
                    "-o", "StrictHostKeyChecking=no",
                    "-i", str(ssh_key),
                    f"{ssh_user}@{ip}",
                    "chmod +x /tmp/uninstall_{tool}.sh".format(tool=tool),
                ]
                try:
                    self._run(chmod_cmd)
                except subprocess.CalledProcessError:
                    pass

                # 3) ejecutar uninstaller y loguear
                ssh_uninstall_cmd = [
                    "ssh",
                    "-o", "StrictHostKeyChecking=no",
                    "-i", str(ssh_key),
                    f"{ssh_user}@{ip}",
                    f"sudo bash /tmp/uninstall_{tool}.sh '{ip}'",
                ]
                with log_path.open("w", encoding="utf-8") as log_file:
                    proc = subprocess.run(
                        ssh_uninstall_cmd,
                        stdout=log_file,
                        stderr=subprocess.STDOUT,
                        text=True,
                    )

                if proc.returncode != 0:
                    results.append({
                        "instance": asdict(instance),
                        "tool": tool,
                        "status": "uninstall_failed",
                        "log_file": str(log_path),
                    })
                    continue

                # En desinstalación no siempre hay validación clara.
                # Comprobamos, por ejemplo, que el binario ya no existe.
                check_cmd = [
                    "ssh",
                    "-o", "StrictHostKeyChecking=no",
                    "-i", str(ssh_key),
                    f"{ssh_user}@{ip}",
                    f"command -v {tool} >/dev/null 2>&1 || echo 'removed'",
                ]
                try:
                    out = self._run(check_cmd)
                    if "removed" in out:
                        results.append({
                            "instance": asdict(instance),
                            "tool": tool,
                            "status": "ok",
                            "log_file": str(log_path),
                        })
                    else:
                        results.append({
                            "instance": asdict(instance),
                            "tool": tool,
                            "status": "validation_unclear",
                            "log_file": str(log_path),
                        })
                except subprocess.CalledProcessError:
                    results.append({
                        "instance": asdict(instance),
                        "tool": tool,
                        "status": "check_failed",
                        "log_file": str(log_path),
                    })

        return results
