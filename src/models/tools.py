from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional


@dataclass
class InstanceTarget:
    """Representa una instancia OpenStack sobre la que se instalarán herramientas."""
    id: str
    name: str
    type: str
    ip_private: str
    ip_floating: Optional[str]
    ip: str
    status: str


@dataclass
class ToolInstallPlan:
    """Plan de instalación: instancia + lista de herramientas."""
    instance: InstanceTarget
    tools: List[str]
    source_json: Path
