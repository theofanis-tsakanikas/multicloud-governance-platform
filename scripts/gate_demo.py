#!/usr/bin/env python3
"""A narrated, paused walkthrough of the gate REFUSING real violations — built to be screen-recorded.

`gate_proof.py` is the terse CI proof ("6 attacks, 6 blocked"). This is its slow, presentable
sibling: one violation at a time, the RED result with the rule that fired, a pause for narration,
then a spotlight on the one rule two independent engines both enforce (PII_WRITE), and finally proof
that the real committed config is clean.

Every mutation lands in a throwaway copy of the repo — the working tree is never touched, so this is
safe to run on a dirty branch, on camera.

    make gate-attack
    GATE_DEMO_PAUSE=0 python3 scripts/gate_demo.py    # no pauses (for a quick self-test)
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gate_proof import ATTACKS, REPO, grant_pii_write  # reuse the mutations, gates and markers

GREEN, RED, DIM, BOLD, CYAN, OFF = "\033[32m", "\033[31m", "\033[2m", "\033[1m", "\033[36m", "\033[0m"
PAUSE = float(os.environ.get("GATE_DEMO_PAUSE", "2.4"))

# Do not copy these into the throwaway — big, irrelevant, or (for .bin) the conftest binary itself.
_IGNORE = shutil.ignore_patterns(
    ".git", ".terraform*", "*.terragrunt-cache*", "promo", "images", "__pycache__", ".venv", "pipelines/data", ".bin"
)


def pause(mult: float = 1.0) -> None:
    time.sleep(PAUSE * mult)


def _copy(root: Path) -> None:
    shutil.copytree(REPO, root, ignore=_IGNORE)


def bar(text: str) -> None:
    print(f"\n{CYAN}{'━' * 74}{OFF}")
    print(f"{CYAN}{BOLD}  {text}{OFF}")
    print(f"{CYAN}{'━' * 74}{OFF}")


def _conftest() -> str | None:
    """The real OPA engine, if we can find it: on PATH, or the repo-local ./.bin/conftest."""
    if shutil.which("conftest"):
        return "conftest"
    local = REPO / ".bin" / "conftest"
    return str(local) if local.exists() else None


def run_attack(attack, index: int, total: int) -> bool:
    bar(f"ATTACK {index}/{total}    {attack.name}")
    print(f"  {DIM}{attack.what}{OFF}")
    pause()
    print("  running the gate against it…")
    with tempfile.TemporaryDirectory(prefix="gate-demo-") as tmp:
        root = Path(tmp) / "repo"
        _copy(root)
        attack.mutate(root)
        proc = subprocess.run(attack.gate, cwd=root, capture_output=True, text=True)
    out = proc.stdout + proc.stderr
    blocked = proc.returncode != 0 and attack.marker in out
    evidence = next((line.strip() for line in out.splitlines() if attack.marker in line), "")
    pause(0.35)
    if blocked:
        print(f"  {RED}{BOLD}✗ BLOCKED{OFF}   exit {proc.returncode}    {GREEN}caught {attack.marker}{OFF}")
        if evidence:
            print(f"  {DIM}{evidence[:82]}{OFF}")
    else:
        print(f"  {RED}(unexpected — did not block){OFF}")
    pause()
    return blocked


def dual_engine() -> None:
    bar("TWO ENGINES, ONE VERDICT    ·    writing to PII")
    print(f"  {DIM}the same violation, judged by two independently-written engines{OFF}")
    pause()
    with tempfile.TemporaryDirectory(prefix="gate-demo-") as tmp:
        root = Path(tmp) / "repo"
        _copy(root)
        grant_pii_write(root)  # data_scientists gets MODIFY on the pii `crm` schema

        print(f"\n  {BOLD}engine 1 · policy_analyzer (Python){OFF}")
        pause(0.5)
        a = subprocess.run([sys.executable, "scripts/policy_analyzer.py"], cwd=root, capture_output=True, text=True)
        print(f"  {RED}{BOLD}✗ PII_WRITE · HIGH{OFF}" if "PII_WRITE" in (a.stdout + a.stderr) else "  (miss)")
        pause()

        print(f"\n  {BOLD}engine 2 · OPA / Rego (conftest){OFF}")
        pause(0.5)
        conftest = _conftest()
        if conftest:
            # Regenerate the grounding pack FROM the mutated config, then let the real Rego engine judge it.
            subprocess.run([sys.executable, "scripts/governance_report.py"], cwd=root, capture_output=True, text=True)
            r = subprocess.run(
                [conftest, "test", "docs/governance/governance_context.json", "--policy", "policy/opa"],
                cwd=root,
                capture_output=True,
                text=True,
            )
            print(f"  {RED}{BOLD}✗ PII_WRITE denied{OFF}" if "PII_WRITE" in (r.stdout + r.stderr) else "  (miss)")
        else:
            print(f"  {DIM}conftest not found — skipping the live Rego run (the analyzer above is the gate){OFF}")
    pause()


def closing(blocked: int, total: int) -> None:
    pause(0.5)
    print(f"\n{RED}{'─' * 74}{OFF}")
    if blocked == total:
        print(f"  {RED}{BOLD}{total} attacks. {total} blocked.{OFF}  {GREEN}{BOLD}The gate is real.{OFF}\n")
    else:
        print(f"  {RED}{BOLD}{blocked}/{total} blocked — {total - blocked} got through. Look here.{OFF}\n")


def main() -> int:
    print(f"{BOLD}Attacking the gate. Every mutation lands in a throwaway copy — the repo is never touched.{OFF}")
    pause()
    total = len(ATTACKS)
    blocked = sum(run_attack(attack, index, total) for index, attack in enumerate(ATTACKS, 1))
    dual_engine()
    closing(blocked, total)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
