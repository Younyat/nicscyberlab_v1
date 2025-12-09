import json
import os
import subprocess
from dataclasses import asdict
from pathlib import Path
from typing import List, Optional, Dict

from src.models.tools import InstanceTarget, ToolInstallPlan


class ToolsInstallerService:
    """
    Servicio de alto nivel para instalar herramientas en las instancias de un escenario.

    Orquesta:
      - lectura de JSONs desde tools-installer-tmp
      - resolución de instancia y herramientas
      - conexión SSH
      - ejecución de instaladores bash
      - validación básica posterior
      - logging local
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

    # ------------------------------------------------------------------
    # Utilidades internas
    # ------------------------------------------------------------------

    def _run(self, cmd: List[str], env: Optional[Dict[str, str]] = None) -> str:
        """Ejecuta un comando y devuelve stdout (lanza excepción si falla)."""
        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=True,
            env=env,
        )
        return result.stdout

    def _load_openstack_env(self) -> Dict[str, str]:
        """
        Carga las variables OS_* desde admin-openrc.sh en un dict de entorno.
        No ejecuta 'source', sino que parsea las líneas export OS_*=...
        """
        env = os.environ.copy()
        if not self.admin_openrc.is_file():
            raise FileNotFoundError(f"No se encontró admin-openrc.sh en {self.admin_openrc}")

        with self.admin_openrc.open("r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line.startswith("export "):
                    continue
                # ejemplo: export OS_AUTH_URL=http://...
                try:
                    _, rest = line.split("export ", 1)
                    key, value = rest.split("=", 1)
                    env[key.strip()] = value.strip()
                except ValueError:
                    # línea no estándar, se ignora
                    continue
        return env

    def _detect_ssh_key(self) -> Path:
        """Busca una clave privada SSH usable en ~/.ssh."""
        ssh_dir = Path.home() / ".ssh"
        candidates: List[Path] = [
            ssh_dir / "id_rsa",
            ssh_dir / "id_ed25519",
        ]
        if ssh_dir.is_dir():
            for item in ssh_dir.iterdir():
                if item.is_file() and "PRIVATE KEY" in item.read_text(errors="ignore"):
                    candidates.append(item)

        for cand in candidates:
            if cand.is_file():
                # Ajustamos permisos por seguridad
                os.chmod(cand, 0o600)
                return cand

        raise RuntimeError("No se encontró ninguna clave privada válida en ~/.ssh")

    def _openstack_get_image_name(self, env: Dict[str, str], instance_name_or_id: str) -> str:
        """Obtiene el nombre de la imagen desde openstack server show."""
        cmd = ["openstack", "server", "show", instance_name_or_id, "-f", "json"]
        out = self._run(cmd, env=env)
        data = json.loads(out)
        image_field = data.get("image")
        if isinstance(image_field, dict):
            return image_field.get("name", "")
        return str(image_field) if image_field is not None else ""

    def _guess_ssh_user(self, image_name: str) -> List[str]:
        """Devuelve una lista ordenada de usuarios candidatos según la imagen."""
        name = image_name.lower()
        if "ubuntu" in name:
            return ["ubuntu", "debian"]
        if "debian" in name:
            return ["debian", "ubuntu"]
        if "kali" in name:
            return ["kali", "root", "ubuntu"]
        if "centos" in name:
            return ["centos", "root"]
        if "fedora" in name:
            return ["fedora", "root", "ec2-user"]
        # fallback genérico
        return ["ubuntu", "debian", "root"]

    def _probe_ssh_user(self, ssh_key: Path, ip: str, candidates: List[str]) -> str:
        """Prueba usuarios por SSH hasta encontrar uno válido."""
        for user in candidates:
            cmd = [
                "ssh",
                "-o", "StrictHostKeyChecking=no",
                "-o", "BatchMode=yes",
                "-i", str(ssh_key),
                f"{user}@{ip}",
                "echo", "ok",
            ]
            try:
                out = self._run(cmd)
                if "ok" in out:
                    return user
            except subprocess.CalledProcessError:
                continue
        raise RuntimeError(f"No fue posible conectar por SSH a {ip} con usuarios candidatos {candidates}")

    def _load_tool_plans(self) -> List[ToolInstallPlan]:
        """Lee todos los *_tools.json en tools-installer-tmp y construye los planes."""
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

    def _installer_path_for(self, tool_name: str) -> Path:
        """Determina el path del instalador bash para una herramienta concreta."""
        # Normalizamos en minúsculas
        t = tool_name.lower()
        tool_dir = self.installers_dir / t
        installer = tool_dir / "install.sh"
        if not installer.is_file():
            raise FileNotFoundError(f"No se encontró instalador para '{tool_name}' en {installer}")
        return installer

    def _log_path_for(self, instance_name: str, tool_name: str) -> Path:
        safe_instance = instance_name.replace(" ", "_")
        safe_tool = tool_name.replace(" ", "_")
        return self.logs_dir / f"{safe_instance}_{safe_tool}_install.log"

    def _validation_command_for(self, tool_name: str) -> str:
        """Comando remoto básico de validación por herramienta."""
        t = tool_name.lower()
        if t == "suricata":
            return "suricata -V"
        if t == "snort":
            return "snort --version"
        if t == "wazuh":
            return "systemctl is-active wazuh-manager"
        if t == "caldera":
            # proceso + puerto, similar a tu bash
            return "pgrep -f 'server.py' >/dev/null 2>&1 && ss -tunlp | grep -q ':8888'"
        if t == "nmap":
            return "nmap --version"
        # fallback genérico
        return f"which {t}"

    # ------------------------------------------------------------------
    # API pública del servicio
    # ------------------------------------------------------------------

    def run_all_plans(self) -> List[Dict]:
        """
        Ejecuta la instalación de todas las herramientas definidas en tools-installer-tmp.
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
                installer_path = self._installer_path_for(tool)
                log_path = self._log_path_for(instance.name, tool)

                # 1) copiar instalador al remoto
                scp_cmd = [
                    "scp",
                    "-o", "StrictHostKeyChecking=no",
                    "-i", str(ssh_key),
                    str(installer_path),
                    f"{ssh_user}@{ip}:/tmp/install_{tool}.sh",
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

                # 2) ajustar permisos remotos
                chmod_cmd = [
                    "ssh",
                    "-o", "StrictHostKeyChecking=no",
                    "-i", str(ssh_key),
                    f"{ssh_user}@{ip}",
                    "chmod +x /tmp/install_{tool}.sh".format(tool=tool),
                ]
                try:
                    self._run(chmod_cmd)
                except subprocess.CalledProcessError:
                    # se intentará ejecutar igualmente; el shell remoto puede manejarlo
                    pass

                # 3) ejecutar instalador remoto y capturar log local
                ssh_install_cmd = [
                    "ssh",
                    "-o", "StrictHostKeyChecking=no",
                    "-i", str(ssh_key),
                    f"{ssh_user}@{ip}",
                    f"sudo bash /tmp/install_{tool}.sh '{ip}'",
                ]
                with log_path.open("w", encoding="utf-8") as log_file:
                    proc = subprocess.run(
                        ssh_install_cmd,
                        stdout=log_file,
                        stderr=subprocess.STDOUT,
                        text=True,
                    )
                if proc.returncode != 0:
                    results.append({
                        "instance": asdict(instance),
                        "tool": tool,
                        "status": "install_failed",
                        "log_file": str(log_path),
                    })
                    continue

                # 4) validación remota
                validate_cmd = [
                    "ssh",
                    "-o", "StrictHostKeyChecking=no",
                    "-i", str(ssh_key),
                    f"{ssh_user}@{ip}",
                    self._validation_command_for(tool),
                ]
                try:
                    subprocess.run(
                        validate_cmd,
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                        text=True,
                        check=True,
                    )
                    results.append({
                        "instance": asdict(instance),
                        "tool": tool,
                        "status": "ok",
                        "log_file": str(log_path),
                    })
                except subprocess.CalledProcessError:
                    results.append({
                        "instance": asdict(instance),
                        "tool": tool,
                        "status": "validation_failed",
                        "log_file": str(log_path),
                    })

        return results
