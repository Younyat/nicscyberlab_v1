from pathlib import Path
import json
from src.services.tools_uninstaller_service import ToolsUninstallerService


def main() -> None:
    repo_root = Path(__file__).resolve().parents[3]
    service = ToolsUninstallerService(repo_root=repo_root)
    results = service.run_all_uninstall_plans()
    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
