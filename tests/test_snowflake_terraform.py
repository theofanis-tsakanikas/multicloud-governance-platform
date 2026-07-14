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


# Signatures of a genuine offline provider-download failure — the ONLY reason this test may skip.
# Anything else (a missing required argument, an unsupported argument, an HCL error) is a real
# config defect and must FAIL, not be laundered into a green skip. That laundering once hid a
# module-wiring bug: the harness omitted two required variables, so init failed on a config error
# and the test skipped — pretending the Snowflake module was validated when it never compiled.
_NETWORK_SKIP_SIGNS = (
    "Failed to install provider",
    "could not download",
    "no available releases",
    "Failed to query available provider packages",
    "Could not retrieve the list of available versions",
    "connection refused",
    "no such host",
    "timeout",
    "dial tcp",
    "TLS handshake",
)


@pytest.mark.skipif(shutil.which("terraform") is None, reason="terraform not installed")
def test_snowflake_terraform_validates():
    init = _run(["terraform", "init", "-backend=false", "-no-color", "-input=false"], _HARNESS)
    if init.returncode != 0:
        if any(sign in init.stderr for sign in _NETWORK_SKIP_SIGNS):
            pytest.skip(f"terraform init: provider download unavailable offline:\n{init.stderr[-500:]}")
        raise AssertionError(f"terraform init failed with a CONFIG error (not a network issue):\n{init.stderr[-800:]}")
    result = _run(["terraform", "validate", "-no-color"], _HARNESS)
    assert result.returncode == 0, f"terraform validate failed:\n{result.stdout}{result.stderr}"
