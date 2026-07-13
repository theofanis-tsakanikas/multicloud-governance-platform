#!/usr/bin/env python3
"""Attack the gate, and prove it holds.

A green badge proves a workflow *ran*. It does not prove the gate *works* — and this repository
learned that the hard way: `dbx-validate.yml` carried a YAML syntax error from the commit that
introduced it, so Checkov, tfsec, `terraform fmt` and `terragrunt validate` were configured,
believed in, and absent from every pull request the project ever had. Twenty runs. Twenty failures.
Not one executed a step.

The lesson is not "check your YAML". It is that **a gate nobody has attacked is a gate nobody has
tested.** So this does the attacking.

Each case below deliberately introduces a violation the platform claims to refuse, runs the real
gate against it, and asserts the gate says no. Every mutation happens inside a throwaway copy of the
repository — the working tree is never touched, and you can run this on a dirty branch without fear.

    python scripts/gate_proof.py          # run every attack
    python scripts/gate_proof.py --list   # just name them
    make gate-proof

Exit code 0 means every attack was blocked. Exit 1 means the gate let something through, which is
the only result here worth losing sleep over.
"""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from datetime import date, timedelta
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

# The attack surface, in the order a reader should meet it.
AWS_GRANTS = "environments/dev/domains/aws/sales_grants.json"
EXCEPTIONS = "environments/dev/policy_exceptions.json"
WORKFLOW = ".github/workflows/dbx-genie.yml"

GREEN, RED, DIM, BOLD, OFF = "\033[32m", "\033[31m", "\033[2m", "\033[1m", "\033[0m"


@dataclass
class Attack:
    name: str
    what: str          # the sentence a human would say about what was done
    expect: str        # the rule / check that must catch it
    mutate: object     # (root: Path) -> None
    gate: list[str]    # the command that must exit non-zero


# ── the mutations ───────────────────────────────────────────────────────────────────────────────

def _grants(root: Path) -> tuple[Path, dict]:
    path = root / AWS_GRANTS
    return path, json.loads(path.read_text())


def grant_pii_to_analysts(root: Path) -> None:
    """The canonical disaster: hand a broad group SELECT on a schema classified `pii`."""
    path, doc = _grants(root)
    for block in doc["schema_grants"]:
        if block["schema"] == "sales_rds_fed.crm":
            block["grants"].append({"principal": "analysts", "privileges": ["SELECT"]})
            break
    path.write_text(json.dumps(doc, indent=2) + "\n")


def grant_pii_write(root: Path) -> None:
    """Worse than reading it: being able to change it."""
    path, doc = _grants(root)
    for block in doc["schema_grants"]:
        if block["schema"] == "sales_rds_fed.crm":
            block["grants"].append({"principal": "data_scientists", "privileges": ["MODIFY"]})
            break
    path.write_text(json.dumps(doc, indent=2) + "\n")


def grant_to_the_world(root: Path) -> None:
    """`account users` is every authenticated principal in the account. It is not a group."""
    path, doc = _grants(root)
    doc["catalog_grants"][0]["grants"].append(
        {"principal": "account users", "privileges": ["USE_CATALOG", "SELECT"]}
    )
    path.write_text(json.dumps(doc, indent=2) + "\n")


def expire_the_exception(root: Path) -> None:
    """Let the documented PII exception lapse. The finding beneath it must come back."""
    path = root / EXCEPTIONS
    doc = json.loads(path.read_text())
    yesterday = (date.today() - timedelta(days=1)).isoformat()
    for exc in doc["exceptions"]:
        exc["expires"] = yesterday
    path.write_text(json.dumps(doc, indent=2) + "\n")


def grant_on_nothing(root: Path) -> None:
    """A grant against a schema that does not exist — a typo that would silently grant nobody
    anything, and look fine in a diff."""
    path, doc = _grants(root)
    doc["schema_grants"].append(
        {"schema": "sales_aws.gold_typo", "grants": [{"principal": "analysts", "privileges": ["SELECT"]}]}
    )
    path.write_text(json.dumps(doc, indent=2) + "\n")


def break_a_workflow(root: Path) -> None:
    """The exact failure this repository actually shipped: a line at column 1 inside a block scalar,
    which terminates it and leaves GitHub unable to parse the file — silently."""
    path = root / WORKFLOW
    lines = path.read_text().splitlines()
    for i, line in enumerate(lines):
        if line.strip().startswith("run: |"):
            lines.insert(i + 2, "> this line is at column 1 and it ends the block scalar")
            break
    path.write_text("\n".join(lines) + "\n")


ATTACKS = [
    Attack(
        name="PII, read by a broad group",
        what="grant `analysts` SELECT on sales_rds_fed.crm — a schema classified `pii`",
        expect="policy_analyzer → PII_BROAD_READ · HIGH",
        mutate=grant_pii_to_analysts,
        gate=[sys.executable, "scripts/policy_analyzer.py"],
    ),
    Attack(
        name="PII, written by a non-admin",
        what="grant `data_scientists` MODIFY on the same PII schema",
        expect="policy_analyzer → PII_WRITE · HIGH",
        mutate=grant_pii_write,
        gate=[sys.executable, "scripts/policy_analyzer.py"],
    ),
    Attack(
        name="A grant to everybody",
        what="grant `account users` USE_CATALOG + SELECT — every principal in the account",
        expect="policy_analyzer → PUBLIC_PRINCIPAL · HIGH",
        mutate=grant_to_the_world,
        gate=[sys.executable, "scripts/policy_analyzer.py"],
    ),
    Attack(
        name="An exception left to rot",
        what="backdate both documented PII exceptions to yesterday",
        expect="policy_analyzer → the suppressed HIGH findings return",
        mutate=expire_the_exception,
        gate=[sys.executable, "scripts/policy_analyzer.py"],
    ),
    Attack(
        name="A grant on a schema that does not exist",
        what="grant SELECT on sales_aws.gold_typo — one character wrong, nobody notices",
        expect="validate_domains → DANGLING_GRANT",
        mutate=grant_on_nothing,
        gate=[sys.executable, "scripts/validate_domains.py"],
    ),
    Attack(
        name="A workflow GitHub cannot read",
        what="put a line at column 1 inside a `run: |` block — the bug this repo actually shipped",
        expect="lint_workflows → unparseable, GitHub would run nothing",
        mutate=break_a_workflow,
        gate=[sys.executable, "scripts/lint_workflows.py"],
    ),
]


def run(attack: Attack, index: int, total: int) -> bool:
    with tempfile.TemporaryDirectory(prefix="gate-proof-") as tmp:
        root = Path(tmp) / "repo"
        shutil.copytree(
            REPO, root,
            ignore=shutil.ignore_patterns(
                ".git", ".terraform*", "*.terragrunt-cache*", "promo", "images",
                "__pycache__", ".venv", "pipelines/data",
            ),
        )
        attack.mutate(root)
        proc = subprocess.run(attack.gate, cwd=root, capture_output=True, text=True)
        blocked = proc.returncode != 0

    print(f"  {BOLD}ATTACK {index}/{total}{OFF}  {attack.name}")
    print(f"            {DIM}{attack.what}{OFF}")
    print(f"            expect: {attack.expect}")

    if blocked:
        evidence = ""
        for line in (proc.stdout + proc.stderr).splitlines():
            if any(k in line for k in ("HIGH", "ERROR", "DANGLING", "RESULT", ".yml:")):
                evidence = line.strip()
                break
        print(f"            {GREEN}BLOCKED{OFF}  exit {proc.returncode}   {DIM}{evidence[:78]}{OFF}\n")
    else:
        print(f"            {RED}*** LET THROUGH — THE GATE DID NOT HOLD ***{OFF}  exit 0\n")
    return blocked


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--list", action="store_true", help="name the attacks and exit")
    args = ap.parse_args()

    if args.list:
        for i, a in enumerate(ATTACKS, 1):
            print(f"  {i}. {a.name:<42} → {a.expect}")
        return 0

    print(f"\n{BOLD}  Attacking the gate.{OFF}  Every mutation lands in a throwaway copy;")
    print(f"  {DIM}your working tree is not touched.{OFF}\n")

    results = [run(a, i, len(ATTACKS)) for i, a in enumerate(ATTACKS, 1)]
    held, total = sum(results), len(results)

    print("  " + "─" * 74)
    if held == total:
        print(f"  {GREEN}{BOLD}{total} attacks. {total} blocked. The gate is real.{OFF}\n")
        return 0
    print(f"  {RED}{BOLD}{total - held} of {total} attacks got through. The gate is not real.{OFF}\n")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
