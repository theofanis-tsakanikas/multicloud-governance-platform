#!/usr/bin/env python3
"""Run the whole offline gate and show every check turn green — built to be screen-recorded.

The counterpart to `gate_demo.py`: where that one shows the gate REFUSING bad config, this shows the
committed config passing every check the CI runs — Terraform formatting, Checkov, the policy
analyzer, the attack proof, the OPA cross-check, the doc-sync checks, and the test suite — as a clean
checklist rather than walls of tool output.

    make gate-green
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
GREEN, RED, DIM, BOLD, GREY, OFF = "\033[32m", "\033[31m", "\033[2m", "\033[1m", "\033[90m", "\033[0m"
PAUSE = float(os.environ.get("GATE_GREEN_PAUSE", "0.45"))

# Prefer the project venv for the tools that live there; fall back to whatever is on PATH.
_VENV = REPO / ".venv" / "bin"
PY = str(_VENV / "python") if (_VENV / "python").exists() else sys.executable
CHECKOV = str(_VENV / "checkov") if (_VENV / "checkov").exists() else shutil.which("checkov")
CONFTEST = shutil.which("conftest") or (str(REPO / ".bin" / "conftest") if (REPO / ".bin" / "conftest").exists() else None)
TFSEC = shutil.which("tfsec") or (str(REPO / ".bin" / "tfsec") if (REPO / ".bin" / "tfsec").exists() else None)
TERRAFORM = shutil.which("terraform")


def _checkov_ok() -> bool:
    # Checkov exits non-zero on any failed check (no soft-fail here), so the exit code IS the verdict
    # — same as _tfsec_ok / _opa_ok beside it. (Grepping the summary line worked, but a crash with no
    # summary would then read as "not passed" for the wrong reason; the return code is unambiguous.)
    r = subprocess.run(
        [CHECKOV, "-d", "infra", "--framework", "terraform", "--config-file", ".checkov.yml", "--compact", "--quiet"],
        cwd=REPO,
        capture_output=True,
        text=True,
    )
    return r.returncode == 0


def _opa_ok() -> bool:
    r = subprocess.run(
        [CONFTEST, "test", "docs/governance/governance_context.json", "--policy", "policy/opa"],
        cwd=REPO,
        capture_output=True,
        text=True,
    )
    return r.returncode == 0


def _tfsec_ok() -> bool:
    r = subprocess.run(
        [TFSEC, "infra", "--config-file", ".tfsec.yml", "--no-color"],
        cwd=REPO,
        capture_output=True,
        text=True,
    )
    return r.returncode == 0


# (label, callable → bool, or None to skip with a reason). A plain command list is run and judged by
# its exit code; a callable lets a check define its own "green".
CHECKS: list = [
    ("Terraform formatting", ([TERRAFORM, "fmt", "-check", "-recursive", "infra/"] if TERRAFORM else "terraform not installed")),
    ("Security scan · Checkov", (_checkov_ok if CHECKOV else "checkov not installed")),
    ("Security scan · tfsec", (_tfsec_ok if TFSEC else "tfsec not installed")),
    ("Every workflow file is readable", [PY, "scripts/lint_workflows.py"]),
    ("Domain config · structure + schema", [PY, "scripts/validate_domains.py"]),
    ("Access policy · least-privilege / PII", [PY, "scripts/policy_analyzer.py"]),
    ("The gate, attacked · 6/6 refused", [PY, "scripts/gate_proof.py"]),
    ("OPA / Rego cross-check", (_opa_ok if CONFTEST else "conftest not installed")),
    ("Governance report in sync", [PY, "scripts/governance_report.py", "--check"]),
    ("Genie artifacts in sync", [PY, "scripts/genie_space.py", "--check"]),
    ("Metrics in sync", [PY, "scripts/governance_metrics.py", "--check"]),
    ("Cost estimate in sync", [PY, "scripts/cost_estimate.py", "--check"]),
    ("Cross-backend · UC ≡ Snowflake", [PY, "scripts/snowflake_backend.py", "--check"]),
    ("Test suite", [PY, "-m", "pytest", "-q"]),
]


def run(entry) -> str:
    """Return 'pass', 'fail', or a skip-reason string."""
    if isinstance(entry, str):
        return entry  # a skip reason
    if callable(entry):
        try:
            return "pass" if entry() else "fail"
        except Exception:
            return "fail"
    r = subprocess.run(entry, cwd=REPO, capture_output=True, text=True)
    return "pass" if r.returncode == 0 else "fail"


def main() -> int:
    print(f"{BOLD}The whole gate, on the committed config — every check the CI runs.{OFF}\n")
    time.sleep(PAUSE)
    failed = 0
    for label, entry in CHECKS:
        result = run(entry)
        if result == "pass":
            print(f"  {GREEN}✓{OFF}  {label}")
        elif result == "fail":
            print(f"  {RED}✗  {label}{OFF}")
            failed += 1
        else:
            print(f"  {GREY}—  {label}  ({result}){OFF}")
        time.sleep(PAUSE)
    print()
    if failed == 0:
        print(f"  {GREEN}{BOLD}ALL CHECKS GREEN.{OFF}  {DIM}The same suite runs on every pull request and every push to main.{OFF}\n")
        return 0
    print(f"  {RED}{BOLD}{failed} check(s) failed.{OFF}\n")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
