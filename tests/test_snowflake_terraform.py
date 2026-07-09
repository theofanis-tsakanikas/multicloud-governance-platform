"""Offline validation of the Snowflake governance Terraform (no account, no credentials).

Mirrors the credential-free discipline of the rest of the platform: `terraform fmt -check`
is fully offline and asserted; `terraform validate` needs the provider downloaded via
`terraform init -backend=false` (network, but no Snowflake connection), so it self-skips
when that download can't happen (offline sandbox). Nothing is ever applied.
"""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

import pytest

_ROOT = Path(__file__).resolve().parent.parent
_HARNESS = _ROOT / "tests" / "terraform" / "snowflake_governance"
_FMT_DIRS = [
    _ROOT / "infra" / "snowflake",
    _ROOT / "infra" / "aws" / "modules" / "data_platform" / "snowflake_governance",
    _HARNESS,
]


def _run(cmd: list[str], cwd: Path) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=300)


@pytest.mark.skipif(shutil.which("terraform") is None, reason="terraform not installed")
@pytest.mark.parametrize("target", _FMT_DIRS, ids=lambda p: p.name)
def test_terraform_fmt_check(target: Path):
    result = _run(["terraform", "fmt", "-check", "-recursive", "-no-color", str(target)], _ROOT)
    assert result.returncode == 0, f"terraform fmt drift under {target}:\n{result.stdout}{result.stderr}"


@pytest.mark.skipif(shutil.which("terraform") is None, reason="terraform not installed")
def test_snowflake_terraform_validates():
    init = _run(["terraform", "init", "-backend=false", "-no-color", "-input=false"], _HARNESS)
    if init.returncode != 0:
        pytest.skip(f"terraform init (provider download) unavailable offline:\n{init.stderr[-500:]}")
    result = _run(["terraform", "validate", "-no-color"], _HARNESS)
    assert result.returncode == 0, f"terraform validate failed:\n{result.stdout}{result.stderr}"
