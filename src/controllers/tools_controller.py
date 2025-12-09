from flask import Blueprint, jsonify
from pathlib import Path

from src.services.tools_installer_service import ToolsInstallerService

tools_bp = Blueprint("tools", __name__)


@tools_bp.route("/api/tools/install", methods=["POST"])
def install_tools():
    """
    Endpoint que recorre todos los *_tools.json en tools-installer-tmp
    y lanza la instalación de herramientas en las instancias.
    """
    repo_root = Path(__file__).resolve().parents[2]
    service = ToolsInstallerService(repo_root=repo_root)
    results = service.run_all_plans()
    return jsonify(results), 200
