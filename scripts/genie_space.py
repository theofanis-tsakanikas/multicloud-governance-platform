#!/usr/bin/env python3
"""Provision the Genie *governance copilot* — the bounded natural-language layer.

This is the **convenience** tier of the governance copilot, and it is
deliberately subordinate to the deterministic core:

    policy_analyzer.py   →  decides what is safe          (the trust, CI-gated)
    governance_report.py →  documents it                 (accountability on demand)
    genie_space.py       →  lets a human ask in English   (read-only convenience)

Genie answers *only* from a small set of governance tables materialized from
``governance_context.json`` — the same facts the report already proved. It has
no authority to grant access, change policy, or read the underlying business
data; it restates governed metadata. This is Readiness-Framework dimension 2,
item 5 in practice: *LLM judgement scoped to where it adds value over
deterministic logic, and bounded everywhere else.*

Because the platform spans AWS + Azure + GCP under one Unity Catalog metastore,
a **single** Genie space answers cross-cloud questions ("which datasets hold PII
and who reads them, across all three clouds?") — there is no per-cloud AI to
maintain. One governance plane, one NL interface.

## What this script does (offline, no credentials)

Generates two deployable artifacts under ``docs/governance/genie/``:

* ``materialize_governance.sql`` — DDL + inserts that load the governance facts
  into a ``platform_governance`` schema. Run this on the serverless SQL
  warehouse; it is the read-only table set Genie is pointed at.
* ``genie_instructions.md`` — the curated space instructions: scope, the
  grounding contract ("answer only from these tables; if the answer is not in
  them, say so"), and benchmark questions.

## Deployment (deferred — mirrors the rest of the platform)

Creating the Genie space itself needs a live workspace + SQL warehouse, so it is
gated behind ``--deploy`` and the Databricks SDK. Like the Terraform/Terragrunt
apply path, provisioning is deliberately not run here; the artifacts are
build-time, the space is deploy-time.

Usage::

    python scripts/genie_space.py                 # regenerate the SQL + instructions
    python scripts/genie_space.py --check          # fail if artifacts are stale
    python scripts/genie_space.py --deploy         # create the space (needs SDK + creds)
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

GOVERNANCE_SCHEMA = "platform_governance.catalog"
GENIE_DIR = Path("docs/governance/genie")
CONTEXT_PATH = Path("docs/governance/governance_context.json")

# Benchmark questions the space must answer from the grounding tables alone.
# These double as an evaluation set: each maps to a deterministic query, so the
# NL answer can be checked against the report it is grounded on.
BENCHMARK_QUESTIONS = [
    "Which datasets are classified as PII, and which groups can read them?",
    "List every object the data_scientists group can access, across all clouds.",
    "Which PII lives in a federated source rather than Unity Catalog managed storage?",
    "Show all open policy findings of MEDIUM severity or higher.",
    "Which accepted-risk exceptions exist, who approved them, and when do they expire?",
    "Which catalogs have no accountable owner?",
]


def _sql_str(value: str | None) -> str:
    """Render a Python value as a SQL string literal (or NULL)."""
    if value is None:
        return "NULL"
    return "'" + value.replace("'", "''") + "'"


def _sql_bool(value: bool) -> str:
    return "TRUE" if value else "FALSE"


def _insert_rows(table: str, columns: list[str], rows: list[list[str]]) -> str:
    if not rows:
        return f"-- (no rows for {table})\n"
    head = f"INSERT INTO {GOVERNANCE_SCHEMA}.{table} ({', '.join(columns)}) VALUES\n"
    values = ",\n".join("  (" + ", ".join(r) + ")" for r in rows)
    return head + values + ";\n"


def render_materialize_sql(ctx: dict) -> str:
    """Build the DDL + inserts that load the governance facts into UC."""
    out: list[str] = []
    out.append("-- Governance grounding tables for the Genie copilot.")
    out.append("-- GENERATED from docs/governance/governance_context.json — do not edit by hand.")
    out.append("-- Run on the serverless SQL warehouse. These tables are READ-ONLY facts;")
    out.append("-- Genie is instructed to answer only from them.")
    out.append("")
    out.append(f"CREATE SCHEMA IF NOT EXISTS {GOVERNANCE_SCHEMA};")
    out.append("")

    # objects
    out.append(
        f"CREATE OR REPLACE TABLE {GOVERNANCE_SCHEMA}.objects (\n"
        "  cloud STRING, domain STRING, object_type STRING, name STRING,\n"
        "  classification STRING, owner STRING, catalog_type STRING\n"
        ");"
    )
    out.append(
        _insert_rows(
            "objects",
            ["cloud", "domain", "object_type", "name", "classification", "owner", "catalog_type"],
            [
                [
                    _sql_str(o["cloud"]),
                    _sql_str(o["domain"]),
                    _sql_str(o["object_type"]),
                    _sql_str(o["name"]),
                    _sql_str(o["classification"]),
                    _sql_str(o["owner"]),
                    _sql_str(o["catalog_type"]),
                ]
                for o in ctx["objects"]
            ],
        )
    )

    # access_matrix
    out.append(
        f"CREATE OR REPLACE TABLE {GOVERNANCE_SCHEMA}.access_matrix (\n"
        "  cloud STRING, domain STRING, object_type STRING, object STRING,\n"
        "  principal STRING, privileges STRING, classification STRING, reads_data BOOLEAN\n"
        ");"
    )
    out.append(
        _insert_rows(
            "access_matrix",
            ["cloud", "domain", "object_type", "object", "principal", "privileges", "classification", "reads_data"],
            [
                [
                    _sql_str(a["cloud"]),
                    _sql_str(a["domain"]),
                    _sql_str(a["object_type"]),
                    _sql_str(a["object"]),
                    _sql_str(a["principal"]),
                    _sql_str(", ".join(a["privileges"])),
                    _sql_str(a["classification"]),
                    _sql_bool(a["reads_data"]),
                ]
                for a in ctx["access_matrix"]
            ],
        )
    )

    # pii_map
    out.append(
        f"CREATE OR REPLACE TABLE {GOVERNANCE_SCHEMA}.pii_map (\n"
        "  cloud STRING, domain STRING, object STRING, storage STRING, readers STRING\n"
        ");"
    )
    out.append(
        _insert_rows(
            "pii_map",
            ["cloud", "domain", "object", "storage", "readers"],
            [
                [
                    _sql_str(p["cloud"]),
                    _sql_str(p["domain"]),
                    _sql_str(p["object"]),
                    _sql_str(p["storage"]),
                    _sql_str(", ".join(p["readers"])),
                ]
                for p in ctx["pii_map"]
            ],
        )
    )

    # policy_findings
    out.append(
        f"CREATE OR REPLACE TABLE {GOVERNANCE_SCHEMA}.policy_findings (\n"
        "  rule STRING, severity STRING, cloud STRING, object STRING, principal STRING,\n"
        "  message STRING, dimension STRING, accepted BOOLEAN, justification STRING\n"
        ");"
    )
    out.append(
        _insert_rows(
            "policy_findings",
            ["rule", "severity", "cloud", "object", "principal", "message", "dimension", "accepted", "justification"],
            [
                [
                    _sql_str(f["rule"]),
                    _sql_str(f["severity"]),
                    _sql_str(f["cloud"]),
                    _sql_str(f["object"]),
                    _sql_str(f["principal"]),
                    _sql_str(f["message"]),
                    _sql_str(f["dimension"]),
                    _sql_bool(f["accepted"]),
                    _sql_str(f["justification"]),
                ]
                for f in ctx["policy_findings"]
            ],
        )
    )

    return "\n".join(out) + "\n"


def render_instructions(ctx: dict) -> str:
    s = ctx["summary"]
    out: list[str] = []
    out.append("# Genie Space — Governance Copilot instructions")
    out.append("")
    out.append("> GENERATED by `scripts/genie_space.py`. These are the space's curated instructions.")
    out.append("")
    out.append("## Purpose")
    out.append("")
    out.append(
        "You are the governance copilot for a Databricks Unity Catalog platform spanning "
        f"{', '.join(s['clouds'])}. You help engineers and auditors understand **who can access "
        "what data, where personal data lives, and which access risks are open or accepted** — "
        "across all clouds, from one place."
    )
    out.append("")
    out.append("## Grounding contract (do not break)")
    out.append("")
    out.append(f"- Answer **only** from the `{GOVERNANCE_SCHEMA}` tables: `objects`, `access_matrix`, `pii_map`, `policy_findings`.")
    out.append("- These tables are the deterministic output of the policy analyzer. They are the source of truth.")
    out.append("- If a question cannot be answered from those tables, say so plainly. **Never guess** access or policy.")
    out.append("- You are read-only. You never grant access, change policy, or read underlying business data.")
    out.append("- For any PII question, always include who can read it and whether the access is an accepted, time-bound exception.")
    out.append("")
    out.append("## Benchmark questions (must answer correctly from the tables)")
    out.append("")
    for q in BENCHMARK_QUESTIONS:
        out.append(f"- {q}")
    out.append("")
    out.append("## Table reference")
    out.append("")
    out.append("- `objects` — every governed object with `classification` and `owner`.")
    out.append("- `access_matrix` — every (principal → privileges) grant; `reads_data` flags content-read access.")
    out.append("- `pii_map` — PII datasets and their exact readers (the headline accountability answer).")
    out.append("- `policy_findings` — least-privilege / PII findings; `accepted=true` rows are documented exceptions.")
    out.append("")
    return "\n".join(out) + "\n"


# --------------------------------------------------------------------------- #
# Orchestration
# --------------------------------------------------------------------------- #


def load_context(repo_root: Path) -> dict:
    path = repo_root / CONTEXT_PATH
    if not path.is_file():
        raise SystemExit(f"missing {CONTEXT_PATH} — run `python scripts/governance_report.py` first to generate the grounding pack.")
    return json.loads(path.read_text(encoding="utf-8"))


def generate_artifacts(repo_root: Path) -> dict[Path, str]:
    ctx = load_context(repo_root)
    return {
        repo_root / GENIE_DIR / "materialize_governance.sql": render_materialize_sql(ctx),
        repo_root / GENIE_DIR / "genie_instructions.md": render_instructions(ctx),
    }


def deploy_space(repo_root: Path) -> int:
    """Create the Genie space via the Databricks SDK (deferred — needs creds).

    Genie spaces are not yet a first-class Terraform resource, so — exactly like
    the documented Genie pattern in the sibling FintelliGuard project — creation
    is an SDK step run at deploy time, not part of `terragrunt apply`.
    """
    try:
        from databricks.sdk import WorkspaceClient  # noqa: F401
    except ImportError:
        print("databricks-sdk not installed — `pip install databricks-sdk` to deploy. Artifacts were still generated.")
        return 0
    print(
        "Deploy is intentionally deferred (no live workspace in CI). With creds configured:\n"
        f"  1. Run docs/governance/genie/materialize_governance.sql on the serverless SQL warehouse.\n"
        f"  2. Create a Genie space over the `{GOVERNANCE_SCHEMA}` schema using the generated instructions.\n"
        "See docs/governance/README.md for the full runbook."
    )
    return 0


def _default_repo_root() -> Path:
    return Path(__file__).resolve().parent.parent


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Generate (and optionally deploy) the Genie governance copilot.")
    parser.add_argument("--root", default=str(_default_repo_root()))
    parser.add_argument("--check", action="store_true", help="fail if generated artifacts are stale")
    parser.add_argument("--deploy", action="store_true", help="create the Genie space (deferred; needs SDK + creds)")
    args = parser.parse_args(argv)

    root = Path(args.root).resolve()
    artifacts = generate_artifacts(root)

    if args.check:
        stale = [
            str(p.relative_to(root)) for p, content in artifacts.items() if not p.is_file() or p.read_text(encoding="utf-8") != content
        ]
        if stale:
            print("STALE Genie artifacts (run `make genie-space`):")
            for p in stale:
                print(f"  - {p}")
            return 1
        print("Genie artifacts are up to date.")
        return 0

    for path, content in artifacts.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        print(f"wrote {path.relative_to(root)}")

    if args.deploy:
        return deploy_space(root)
    return 0


if __name__ == "__main__":
    sys.exit(main())
