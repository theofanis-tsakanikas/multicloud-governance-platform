"""Pytest configuration: make scripts/validate_domains.py importable."""

import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPTS_DIR = REPO_ROOT / "scripts"
PIPELINES_DIR = REPO_ROOT / "pipelines"

for _d in (SCRIPTS_DIR, PIPELINES_DIR):
    if str(_d) not in sys.path:
        sys.path.insert(0, str(_d))
