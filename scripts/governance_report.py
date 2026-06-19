#!/usr/bin/env python3
"""Generate governance documentation from the committed config — accountability on demand.

Two artifacts, both derived deterministically from the domain JSON + the policy
analyzer (no cloud, no credentials, no LLM):

1. ``docs/governance/REPORT.md`` — human-readable **data governance report**:
   the per-cloud object inventory, the access matrix (who can touch what), the
   PII map (where personal data lives and exactly who can read it), and the
   policy-scan summary including accepted-risk exceptions. This is the
   EU-AI-Act / GDPR "technical documentation generated from the system, kept in
   sync with the code" (Readiness Framework dimension 4).

2. ``docs/governance/governance_context.json`` — the machine-readable **grounding
   pack**: the same facts as structured JSON. This is the bounded source of
   truth the Genie governance space (``genie_space.py``) is instructed to answer
   from — so the NL layer can only restate facts this report already proved,
   never invent them.

Regenerating is idempotent; CI can assert the committed artifacts match a fresh
render (``--check``) so the documentation can never silently drift from the code.

Usage::

    python scripts/governance_report.py            # write both artifacts
    python scripts/governance_report.py --check     # fail if artifacts are stale
    python scripts/governance_report.py --stdout    # print the Markdown, write nothing
"""

from __future__ import annotations

import argparse
import datetime as _dt
import json
import sys
from pathlib import Path

from governance_model import GovernanceModel, build_model
from policy_analyzer import AnalysisResult, run_analysis

DEFAULT_REPORT = Path("docs/governance/REPORT.md")
DEFAULT_CONTEXT = Path("docs/governance/governance_context.json")

# Privileges that expose data contents (used to answer "who can read X").
_READ = {"SELECT", "READ_VOLUME", "READ_FILES"}


# --------------------------------------------------------------------------- #
# Structured context (grounding pack)
# --------------------------------------------------------------------------- #


def build_context(model: GovernanceModel, analysis: AnalysisResult) -> dict:
    """Assemble the machine-readable governance facts that ground the NL layer."""
    objects = [
        {
            "cloud": s.cloud,
            "domain": s.domain,
            "object_type": s.object_type,
            "name": s.fqn,
            "classification": s.classification,
            "owner": s.owner,
            "catalog_type": s.catalog_type,
        }
        for s in model.securables
    ]

    access = [
        {
            "cloud": g.cloud,
            "domain": g.domain,
            "object_type": g.object_type,
            "object": g.fqn,
            "principal": g.principal,
            "privileges": list(g.privileges),
            "classification": g.classification,
            "reads_data": bool(set(g.privileges) & _READ),
        }
        for g in model.grants
    ]

    # "Which datasets have PII and who reads them?" — answered deterministically.
    pii_map = []
    for s in model.securables:
        if s.classification == "pii" and s.object_type in ("schema", "volume"):
            readers = sorted(
                {g.principal for g in model.grants if g.object_type == s.object_type and g.fqn == s.fqn and set(g.privileges) & _READ}
            )
            pii_map.append(
                {
                    "cloud": s.cloud,
                    "domain": s.domain,
                    "object": s.fqn,
                    "storage": "federated" if s.catalog_type == "FEDERATED" else "uc_managed",
                    "readers": readers,
                }
            )

    findings = [
        {
            "rule": f.rule,
            "severity": f.severity,
            "cloud": f.cloud,
            "object": f.object_ref,
            "principal": f.principal,
            "message": f.message,
            "dimension": f.dimension,
            "accepted": f.accepted,
            "justification": f.justification,
        }
        for f in analysis.findings
    ]

    return {
        "generated_at": _dt.date.today().isoformat(),
        "summary": {
            "clouds": sorted({s.cloud for s in model.securables}),
            "domains": [d for _, d in model.domains()],
            "object_count": len(model.securables),
            "grant_count": len(model.grants),
            "pii_objects": len(pii_map),
            "policy_counts": analysis.counts(),
        },
        "objects": objects,
        "access_matrix": access,
        "pii_map": pii_map,
        "policy_findings": findings,
    }


# --------------------------------------------------------------------------- #
# Markdown rendering
# --------------------------------------------------------------------------- #


def _table(headers: list[str], rows: list[list[str]]) -> str:
    line = "| " + " | ".join(headers) + " |"
    sep = "| " + " | ".join("---" for _ in headers) + " |"
    body = "\n".join("| " + " | ".join(r) + " |" for r in rows)
    return "\n".join([line, sep, body]) if rows else f"{line}\n{sep}\n| _none_ |" + " |" * (len(headers) - 1)


def render_markdown(ctx: dict) -> str:
    s = ctx["summary"]
    out: list[str] = []
    out.append("# Data Governance Report")
    out.append("")
    out.append(
        "> Generated by `scripts/governance_report.py` from the committed domain config. "
        "Do not edit by hand — run `make governance-report`. "
        "This document is the EU-AI-Act / GDPR technical documentation for the platform's "
        "access model, kept in sync with the code by CI (`--check`)."
    )
    out.append("")
    out.append(f"- **Generated:** {ctx['generated_at']}")
    out.append(f"- **Clouds:** {', '.join(s['clouds'])}")
    out.append(f"- **Domains:** {', '.join(s['domains'])}")
    out.append(f"- **Governed objects:** {s['object_count']} · **grants:** {s['grant_count']} · **PII datasets:** {s['pii_objects']}")
    pc = s["policy_counts"]
    out.append(
        f"- **Policy scan:** {pc['HIGH']} high · {pc['MEDIUM']} medium · {pc['LOW']} low · "
        f"{pc['INFO']} info · {pc['ACCEPTED']} accepted (documented exceptions)"
    )
    out.append("")

    # ---- PII map (the headline answer) -----------------------------------
    out.append("## PII map — where personal data lives and who can read it")
    out.append("")
    if ctx["pii_map"]:
        rows = [
            [
                p["cloud"],
                f"`{p['object']}`",
                p["storage"],
                ", ".join(p["readers"]) or "_admins only_",
            ]
            for p in ctx["pii_map"]
        ]
        out.append(_table(["Cloud", "Dataset", "Storage", "Readers (SELECT/READ)"], rows))
    else:
        out.append("_No objects are classified `pii`._")
    out.append("")

    # ---- policy findings --------------------------------------------------
    out.append("## Policy findings")
    out.append("")
    open_findings = [f for f in ctx["policy_findings"] if not f["accepted"]]
    accepted = [f for f in ctx["policy_findings"] if f["accepted"]]
    if open_findings:
        rows = [[f["severity"], f["rule"], f["cloud"], f"`{f['object']}`", f["principal"] or "—", f["dimension"]] for f in open_findings]
        out.append(_table(["Severity", "Rule", "Cloud", "Object", "Principal", "Framework dimension"], rows))
    else:
        out.append("_No open findings._")
    out.append("")
    out.append("### Accepted risks (documented exceptions)")
    out.append("")
    if accepted:
        rows = [[f["rule"], f"`{f['object']}`", f["principal"] or "—", f["justification"]] for f in accepted]
        out.append(_table(["Rule", "Object", "Principal", "Justification (approved & time-bound)"], rows))
    else:
        out.append("_No accepted-risk exceptions._")
    out.append("")

    # ---- per-cloud inventory ---------------------------------------------
    out.append("## Object inventory")
    out.append("")
    for cloud in s["clouds"]:
        out.append(f"### {cloud}")
        out.append("")
        rows = [
            [
                o["object_type"],
                f"`{o['name']}`",
                o["classification"] or "—",
                o["owner"] or "—",
                o["catalog_type"] or "—",
            ]
            for o in ctx["objects"]
            if o["cloud"] == cloud
        ]
        out.append(_table(["Type", "Name", "Classification", "Owner", "Catalog type"], rows))
        out.append("")

    # ---- access matrix ----------------------------------------------------
    out.append("## Access matrix")
    out.append("")
    rows = [
        [
            a["cloud"],
            f"`{a['object']}`",
            a["classification"] or "—",
            a["principal"],
            ", ".join(a["privileges"]),
        ]
        for a in ctx["access_matrix"]
    ]
    out.append(_table(["Cloud", "Object", "Classification", "Principal", "Privileges"], rows))
    out.append("")

    return "\n".join(out) + "\n"


# --------------------------------------------------------------------------- #
# Orchestration
# --------------------------------------------------------------------------- #


def generate(repo_root: str | Path) -> tuple[str, dict]:
    repo_root = Path(repo_root).resolve()
    model = build_model(repo_root)
    analysis = run_analysis(repo_root)
    ctx = build_context(model, analysis)
    return render_markdown(ctx), ctx


def _default_repo_root() -> Path:
    return Path(__file__).resolve().parent.parent


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Generate the data governance report + grounding context.")
    parser.add_argument("--root", default=str(_default_repo_root()))
    parser.add_argument("--check", action="store_true", help="fail if committed artifacts are stale (no write)")
    parser.add_argument("--stdout", action="store_true", help="print Markdown to stdout, write nothing")
    args = parser.parse_args(argv)

    root = Path(args.root).resolve()
    markdown, ctx = generate(root)
    context_json = json.dumps(ctx, indent=2) + "\n"

    if args.stdout:
        print(markdown)
        return 0

    report_path = root / DEFAULT_REPORT
    context_path = root / DEFAULT_CONTEXT

    if args.check:
        stale = []

        # Compare ignoring the volatile generated_at date so CI is deterministic.
        def _strip_date(text: str) -> str:
            return "\n".join(line for line in text.splitlines() if "Generated" not in line and '"generated_at"' not in line)

        for path, fresh in ((report_path, markdown), (context_path, context_json)):
            existing = path.read_text(encoding="utf-8") if path.is_file() else ""
            if _strip_date(existing) != _strip_date(fresh):
                stale.append(str(path.relative_to(root)))
        if stale:
            print("STALE governance artifacts (run `make governance-report`):")
            for p in stale:
                print(f"  - {p}")
            return 1
        print("governance artifacts are up to date.")
        return 0

    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(markdown, encoding="utf-8")
    context_path.write_text(context_json, encoding="utf-8")
    print(f"wrote {report_path.relative_to(root)} and {context_path.relative_to(root)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
