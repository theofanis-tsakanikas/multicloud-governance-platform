# Governance Copilot

A Responsible-AI governance layer over the multi-cloud Unity Catalog platform. It
answers — provably, and in plain English — the questions an auditor or a CTO
actually asks:

> *Who can access what data? Where does personal data live, and who can read it?
> Which access risks are open, and which are accepted, by whom, and until when?*

It is built **trust-first**: a deterministic analyzer decides what is safe (and
gates CI), documentation is generated from that analysis, and only then does a
natural-language layer sit on top — bounded to restate facts the analyzer already
proved. No LLM is in the decision path.

```
            environments/dev/domains/*.json        (the governed config)
                          │
        scripts/governance_model.py                normalize → objects + grants + classification
                          │
   ┌──────────────────────┼───────────────────────────────────────────┐
   ▼                      ▼                                            ▼
policy_analyzer.py   governance_report.py                       genie_space.py
deterministic        docs/governance/REPORT.md                  docs/governance/genie/*
least-privilege +    + governance_context.json                  materialize SQL + space
PII rules            (EU-AI-Act / GDPR technical doc            instructions, grounded
→ CI GATE             + the grounding pack)                      ONLY on the report
(blocks on HIGH)                                                 (read-only convenience)
```

## Why this design (and not "a chatbot")

The platform's thesis is **one governance plane across three clouds**. The copilot
honours it: a **single** Genie space answers cross-cloud questions because Unity
Catalog federates AWS + Azure + GCP — there is no per-cloud AI to maintain.

And the intelligence is in the *deterministic* layer, not the LLM. Genie is the
convenience tier; it cannot grant access, change policy, or read business data. It
restates the governance facts the analyzer computed. This is the Responsible-AI
Readiness Framework, dimension 2 item 5, applied to ourselves: *LLM judgement
scoped to where it adds value over deterministic logic, and bounded everywhere
else.*

## The pieces

| File | Role | Framework dimension |
|---|---|---|
| `scripts/governance_model.py` | Parse the domain JSON into objects + grants with data classification resolved. | 1 · Data quality & lineage |
| `scripts/policy_analyzer.py` | Deterministic least-privilege / PII rules. **Exits non-zero on unacknowledged HIGH** — the CI gate. | 4 · Governance as code |
| `environments/dev/policy_exceptions.json` | Documented, approved, time-bound deviations. Expired exceptions stop suppressing. | 4 · Governance as code |
| `scripts/governance_report.py` | `docs/governance/REPORT.md` (EU-AI-Act / GDPR technical doc) + `governance_context.json` (grounding pack). | 4 · Governance as code |
| `scripts/genie_space.py` | Genie space SQL + grounding-contract instructions, derived from the report. | 2 · Guardrails & safety |

## Data classification convention

Schemas carry an optional `"classification"` (`public` < `internal` <
`confidential` < `pii`) and catalogs an optional `"owner"`, declared in
`*_infra.json`. Terraform ignores both (it consumes the JSON via `jsondecode` +
`merge`/`lookup`, so unknown keys pass through harmlessly) — they exist purely for
the governance layer. A volume inherits its schema's classification unless it sets
its own.

## Policy rules

| Rule | Severity | Concern |
|---|---|---|
| `PUBLIC_PRINCIPAL` | HIGH | data granted to an all-users / public principal |
| `PII_BROAD_READ` | HIGH | PII readable by a principal not on the allowlist |
| `PII_WRITE` | HIGH | PII writable/modifiable by a non-admin |
| `SENSITIVE_ALL_PRIVILEGES` | HIGH | `ALL_PRIVILEGES` on confidential/PII data (non-admin) |
| `MANAGE_NONADMIN` | MEDIUM | `MANAGE` (can alter grants) held by a non-admin |
| `ALL_PRIVILEGES_NONADMIN` | MEDIUM | `ALL_PRIVILEGES` sprawl beyond admins/owners |
| `UNCLASSIFIED_SCHEMA` | LOW | schema with no data classification |
| `UNOWNED_CATALOG` | LOW | catalog with no accountable owner |
| `FEDERATED_PII` | INFO | PII in federated (non-UC-managed) storage |

Only **unacknowledged HIGH** findings fail CI (use `--strict` to also fail on
MEDIUM). MEDIUM/LOW/INFO are advisory; they appear in the report so a human
decides.

## Exceptions: governance-as-code, not silence

Intentional deviations are never hard-coded away. They live in
`policy_exceptions.json` with a `justification`, an `approved_by`, and an
`expires`. A matching **unexpired** exception downgrades a finding to an
*accepted risk* — reported, not gating. An **expired** one stops suppressing, so
the risk re-surfaces for review. The committed config carries two: the CRM team
reading customer PII, and data science reading pseudonymised web PII — each with a
DPIA reference and an expiry. That is the auditable who/what/why/until.

## Provability, telemetry & FinOps (the layers around the core)

The deterministic core is wrapped in tooling that makes it *provable*, *trackable*,
and *costed* — all offline:

| Concern | What | Where |
|---|---|---|
| **Provably correct** | A golden corpus of crafted violations asserts every rule fires (and clean config stays quiet). | `tests/golden/corpus.json` |
| **Second opinion** | The three gating rules re-implemented in **OPA/Rego** — two engines must agree the config is clean. | [`policy/opa/`](../../policy/opa/README.md) |
| **Platform-native findings** | The analyzer emits **SARIF 2.1.0**, so findings appear in the GitHub Security tab with accepted risks shown as suppressions. | `policy_analyzer.py --format sarif` |
| **Versioned contract** | Domain JSON validated against published **JSON Schema** (+ IDE autocomplete), on top of the structural validator. | [`schema/`](../../schema/README.md) |
| **Telemetry** | Trendable posture / coverage / PII / exception-timeline metrics — diff governance health between PRs. | [`metrics.json`](metrics.json) |
| **Cost & carbon** | A multi-cloud + Databricks cost + carbon **floor** that fills Infracost's blind spots. | [`COST.md`](COST.md) |
| **Live drift** | Reconcile the *declared* grants against the *live* Unity Catalog (deferred — SDK + creds). | `scripts/catalog_drift.py` |
| **Expiry foresight** | A non-gating warning when an exception is about to expire, before the risk re-opens and breaks a build. | `policy_analyzer.py --warn-expiring` |
| **Governance over data in motion** | A real bronze→silver→gold medallion (offline sqlite) proves PII-minimisation in gold and reconciles observed PII against the declared classification. | [`pipelines/`](../../pipelines/README.md) → `data_profile.json` |
| **Self-contained dashboard** | A static, no-JS, no-server page rendering posture / PII / data reconciliation / cost from the committed artifacts; published to GitHub Pages. | [`dashboard/index.html`](dashboard/index.html) |

## Commands

```bash
make demo                 # the entire offline governance pipeline end-to-end (no cloud, ~30s)
make demo-data            # data in motion: generate → medallion → profile → dashboard
make dashboard            # render the static governance dashboard (docs/governance/dashboard/)
make policy-scan          # deterministic analysis; exits non-zero on unacknowledged HIGH
make governance-report    # regenerate REPORT.md + context + metrics + cost + Genie artifacts
make metrics              # print governance telemetry
make cost-estimate        # regenerate the cost + carbon floor
make opa                  # OPA/Rego cross-check (needs conftest)

python scripts/policy_analyzer.py --format json      # machine-readable findings
python scripts/policy_analyzer.py --format sarif      # SARIF for the Security tab
python scripts/policy_analyzer.py --strict            # also gate on MEDIUM
python scripts/policy_analyzer.py --warn-expiring 30  # warn on soon-to-expire exceptions
python scripts/governance_report.py --check           # CI: fail if docs drift from config
python scripts/catalog_drift.py --live                # reconcile vs live UC (needs SDK + creds)
```

CI (`.github/workflows/dbx-config-validate.yml`, offline, no cloud creds) runs the
analyzer as a gate and asserts the committed docs + Genie artifacts match a fresh
render — so the EU-AI-Act documentation can never silently drift from the code.

## Deploying the Genie layer (deferred)

Genie spaces are not yet a first-class Terraform resource, so — like the rest of
the platform's apply path — provisioning is a deploy-time SDK step, not part of
`terragrunt apply`. With a workspace + SQL warehouse and credentials configured:

1. Run `docs/governance/genie/materialize_governance.sql` on the serverless SQL
   warehouse to load the read-only governance tables into `platform_governance`.
2. Create a Genie space over that schema, pasting
   `docs/governance/genie/genie_instructions.md` as the space instructions.
3. The space now answers the benchmark questions in those instructions — grounded
   strictly on the tables, which are the analyzer's output.

`python scripts/genie_space.py --deploy` documents this runbook and is the hook
for SDK-based provisioning once a workspace exists.
