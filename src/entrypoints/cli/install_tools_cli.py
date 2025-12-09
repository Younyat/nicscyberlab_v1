from pathlib import Path
import json
from src.services.tools_installer_service import ToolsInstallerService


def main() -> None:
    repo_root = Path(__file__).resolve().parents[3]  # sube desde src/entrypoints/cli
    service = ToolsInstallerService(repo_root=repo_root)
    results = service.run_all_plans()
    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
