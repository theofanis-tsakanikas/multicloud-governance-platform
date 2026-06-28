#!/usr/bin/env python3
"""Render a single, self-contained governance dashboard — Level A.

One static ``index.html`` (inline CSS + inline SVG, **no JS, no CDN, no server**)
built deterministically from the governance artifacts:

* ``docs/governance/metrics.json``           — posture, coverage, exception timeline
* ``docs/governance/governance_context.json`` — PII map, accepted risks
* ``docs/governance/data_profile.json``       — observed-vs-declared reconciliation (Level B)
* ``scripts/cost_estimate.py``                — cost + carbon floor

This is the "wow in 10 seconds" face of the platform that a reviewer can open
with a double-click — no Grafana, no Prometheus, no live data. It visualizes
exactly the governance story (posture, PII, drift, cost), staying offline-first
like the rest of the repo. CI ``--check`` keeps it in sync with the artifacts.

Usage::

    python scripts/governance_dashboard.py            # write docs/governance/dashboard/index.html
    python scripts/governance_dashboard.py --check     # fail if the committed HTML is stale
    python scripts/governance_dashboard.py --stdout    # print HTML, write nothing
"""

from __future__ import annotations

import argparse
import html
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import cost_estimate  # noqa: E402

DASHBOARD = Path("docs/governance/dashboard/index.html")
_METRICS = Path("docs/governance/metrics.json")
_CONTEXT = Path("docs/governance/governance_context.json")
_PROFILE = Path("docs/governance/data_profile.json")


def _load(path: Path) -> dict | None:
    return json.loads(path.read_text(encoding="utf-8")) if path.is_file() else None


def _bar(pct: float, color: str) -> str:
    pct = max(0.0, min(100.0, pct))
    return (
        f'<svg viewBox="0 0 100 8" preserveAspectRatio="none" class="bar">'
        f'<rect width="100" height="8" rx="4" fill="#23304a"/>'
        f'<rect width="{pct:.1f}" height="8" rx="4" fill="{color}"/></svg>'
    )


def _card(label: str, value, accent: str) -> str:
    return f'<div class="card"><div class="num" style="color:{accent}">{value}</div><div class="lbl">{html.escape(label)}</div></div>'


def render_html(metrics: dict, context: dict | None, profile: dict | None, cost: dict) -> str:
    m = metrics
    post = m["posture"]
    cov = m["coverage"]
    foot = m["footprint"]
    exc = m["exceptions"]

    gating_color = "#ff5c5c" if post["gating"] else "#3ddc97"

    out: list[str] = []
    out.append("<!doctype html><html lang='en'><head><meta charset='utf-8'>")
    out.append("<meta name='viewport' content='width=device-width, initial-scale=1'>")
    out.append("<title>Governance Dashboard — Multi-Cloud Governance Platform</title>")
    out.append(
        "<style>"
        ":root{--bg:#0d1426;--panel:#141d33;--ink:#e7ecf5;--mut:#8a9bc0;--line:#23304a}"
        "*{box-sizing:border-box}"
        "body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.5 -apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif}"
        ".wrap{max-width:1080px;margin:0 auto;padding:32px 20px 64px}"
        "h1{font-size:26px;margin:0 0 4px}"
        "h2{font-size:16px;margin:32px 0 12px;color:var(--mut);text-transform:uppercase;letter-spacing:.06em}"
        ".sub{color:var(--mut);margin:0 0 8px}"
        ".grid{display:grid;gap:14px;grid-template-columns:repeat(auto-fit,minmax(150px,1fr))}"
        ".card{background:var(--panel);border:1px solid var(--line);border-radius:12px;padding:16px}"
        ".num{font-size:30px;font-weight:700;line-height:1} .lbl{color:var(--mut);font-size:13px;margin-top:6px}"
        ".panel{background:var(--panel);border:1px solid var(--line);border-radius:12px;padding:18px}"
        ".bar{width:100%;height:8px;display:block;margin:6px 0 2px}"
        "table{width:100%;border-collapse:collapse;font-size:14px}"
        "th,td{text-align:left;padding:8px 10px;border-bottom:1px solid var(--line)}"
        "th{color:var(--mut);font-weight:600} code{background:#1b2640;padding:1px 6px;border-radius:5px;font-size:13px}"
        ".pill{display:inline-block;padding:2px 9px;border-radius:999px;font-size:12px;font-weight:600}"
        ".ok{background:#10341f;color:#3ddc97} .bad{background:#3a1620;color:#ff5c5c} .warn{background:#3a2e12;color:#f5c451}"
        ".two{display:grid;gap:14px;grid-template-columns:1fr 1fr} @media(max-width:720px){.two{grid-template-columns:1fr}}"
        ".foot{color:var(--mut);font-size:13px;margin-top:40px;border-top:1px solid var(--line);padding-top:16px}"
        "</style></head><body><div class='wrap'>"
    )

    # ---- header ----------------------------------------------------------- #
    out.append("<h1>Multi-Cloud Governance Dashboard</h1>")
    out.append(
        f"<p class='sub'>One governance plane across <b>{', '.join(foot['clouds'])}</b> · "
        f"{len(foot['domains'])} domains · {foot['objects']} governed objects · {foot['grants']} grants</p>"
    )
    status = "<span class='pill bad'>GATE: BLOCKED</span>" if post["gating"] else "<span class='pill ok'>GATE: PASSING</span>"
    out.append(f"<p>{status} &nbsp; <span class='sub'>deterministic least-privilege / PII analysis</span></p>")

    # ---- posture ---------------------------------------------------------- #
    out.append("<h2>Policy posture</h2><div class='grid'>")
    out.append(_card("Gating (unack. HIGH)", post["gating"], gating_color))
    out.append(_card("High", post["open_high"], "#ff5c5c"))
    out.append(_card("Medium", post["open_medium"], "#f5c451"))
    out.append(_card("Low", post["open_low"], "#7aa2f7"))
    out.append(_card("Accepted risks", post["accepted_risks"], "#8a9bc0"))
    out.append("</div>")

    # ---- coverage --------------------------------------------------------- #
    out.append("<h2>Governance coverage</h2><div class='two'>")
    out.append(
        f"<div class='panel'><b>{cov['schemas_classified_pct']}%</b> schemas classified "
        f"<span class='sub'>({cov['schemas_classified']}/{cov['schemas']})</span>"
        f"{_bar(cov['schemas_classified_pct'], '#3ddc97')}</div>"
    )
    out.append(
        f"<div class='panel'><b>{cov['catalogs_owned_pct']}%</b> catalogs owned "
        f"<span class='sub'>({cov['catalogs_owned']}/{cov['catalogs']})</span>"
        f"{_bar(cov['catalogs_owned_pct'], '#7aa2f7')}</div>"
    )
    out.append("</div>")

    # ---- PII map ---------------------------------------------------------- #
    if context and context.get("pii_map"):
        out.append("<h2>PII map — where personal data lives & who reads it</h2><div class='panel'><table>")
        out.append("<tr><th>Cloud</th><th>Dataset</th><th>Storage</th><th>Readers</th></tr>")
        for p in context["pii_map"]:
            readers = ", ".join(p["readers"]) or "<i>admins only</i>"
            out.append(
                f"<tr><td>{html.escape(p['cloud'])}</td><td><code>{html.escape(p['object'])}</code></td>"
                f"<td>{html.escape(p['storage'])}</td><td>{readers}</td></tr>"
            )
        out.append("</table></div>")

    # ---- data reconciliation (Level B) ------------------------------------ #
    if profile:
        ps = profile["summary"]
        gold_pill = "<span class='pill ok'>PII-minimised</span>" if ps["gold_pii_minimised"] else "<span class='pill bad'>PII leak</span>"
        drift_pill = (
            "<span class='pill ok'>no drift</span>"
            if ps["classification_drift"] == 0
            else f"<span class='pill bad'>{ps['classification_drift']} drift</span>"
        )
        out.append("<h2>Data reconciliation — declared vs observed</h2>")
        out.append("<div class='grid'>")
        out.append(_card("Rows profiled", f"{ps['rows_profiled']:,}", "#e7ecf5"))
        out.append(_card("Governed schemas", ps["governed_schemas"], "#e7ecf5"))
        out.append(_card("Schemas with PII", ps["schemas_with_pii"], "#f5c451"))
        out.append(_card("Gold tables", ps["gold_tables"], "#e7ecf5"))
        out.append("</div>")
        out.append(
            f"<p style='margin-top:12px'>Gold layer: {gold_pill} &nbsp; Classification: {drift_pill} "
            "<span class='sub'>(observed PII columns match their declared classification)</span></p>"
        )

    # ---- exceptions timeline ---------------------------------------------- #
    accepted = [f for f in (context.get("policy_findings", []) if context else []) if f.get("accepted")]
    out.append("<h2>Accepted risks &amp; exception timeline</h2><div class='panel'>")
    out.append(
        f"<p class='sub'>{exc['total']} documented exceptions · {exc['expiring_within_30d']} expire ≤30d · "
        f"{exc['expiring_within_60d']} ≤60d · {exc['expiring_within_90d']} ≤90d · {exc['expired']} expired</p>"
    )
    if accepted:
        out.append("<table><tr><th>Rule</th><th>Object</th><th>Principal</th><th>Justification</th></tr>")
        for f in accepted:
            out.append(
                f"<tr><td>{html.escape(f['rule'])}</td><td><code>{html.escape(f['object'])}</code></td>"
                f"<td>{html.escape(f['principal'] or '—')}</td><td>{html.escape(f['justification'])}</td></tr>"
            )
        out.append("</table>")
    out.append("</div>")

    # ---- cost & carbon ---------------------------------------------------- #
    out.append("<h2>Cost &amp; carbon floor</h2><div class='grid'>")
    out.append(_card(f"Total /month ({cost['currency']})", f"~{cost['total_monthly_usd']:,.0f}", "#3ddc97"))
    out.append(_card("Databricks /month", f"~{cost['databricks']['monthly_usd']:,.0f}", "#7aa2f7"))
    out.append(_card("Infra /month", f"~{cost['infra_total_usd']:,.0f}", "#7aa2f7"))
    out.append(_card("Carbon kg CO₂e/mo", f"~{cost['carbon']['warehouse_kg_co2e_per_month']:,.0f}", "#f5c451"))
    out.append("</div>")

    out.append(
        "<p class='foot'>Generated by <code>scripts/governance_dashboard.py</code> from the committed governance "
        "artifacts — fully offline, no live data, no server. Regenerate with <code>make dashboard</code>; "
        "CI asserts it is in sync.</p>"
    )
    out.append("</div></body></html>")
    return "\n".join(out) + "\n"


def generate(repo_root: str | Path) -> str:
    repo_root = Path(repo_root).resolve()
    metrics = _load(repo_root / _METRICS)
    if metrics is None:
        raise SystemExit(f"missing {_METRICS} — run `make governance-report` first.")
    context = _load(repo_root / _CONTEXT)
    profile = _load(repo_root / _PROFILE)
    _, cost = cost_estimate.generate(repo_root)
    return render_html(metrics, context, profile, cost)


def _default_repo_root() -> Path:
    return Path(__file__).resolve().parent.parent


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Render the static governance dashboard (offline, deterministic).")
    parser.add_argument("--root", default=str(_default_repo_root()))
    parser.add_argument("--check", action="store_true", help="fail if the committed dashboard is stale")
    parser.add_argument("--stdout", action="store_true", help="print HTML, write nothing")
    args = parser.parse_args(argv)

    root = Path(args.root).resolve()
    html_doc = generate(root)

    if args.stdout:
        print(html_doc, end="")
        return 0

    path = root / DASHBOARD
    if args.check:
        existing = path.read_text(encoding="utf-8") if path.is_file() else ""
        if existing != html_doc:
            print(f"STALE dashboard (run `make dashboard`): {DASHBOARD}")
            return 1
        print("dashboard is up to date.")
        return 0

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(html_doc, encoding="utf-8")
    print(f"wrote {DASHBOARD}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
