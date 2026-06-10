# Promo Video — Master Plan (Multi-Cloud Governance Platform)

## Read this first — why this promo is different
The other portfolio projects have an interactive app to film. **This one deliberately does not** —
it's a **platform / Infrastructure-as-Code** project: Databricks Unity Catalog governance
provisioned across AWS, Azure and GCP with Terragrunt. Bolting a fake dashboard on it would *lower*
the credibility with the exact senior/platform audience it's meant to impress.

So the hero here is built from what this project actually *is*: **a terminal, a dependency graph,
cloud consoles, and CI artifacts.** This is the standard, respected way to demo a platform-eng
project. Play to that strength instead of forcing a UI.

## Goal & audience
Audience skews senior: platform engineers, staff DEs, hiring managers for infra roles. They must
grasp in **~15 seconds**:
> *One command provisions governed Databricks Unity Catalog across three clouds — secrets never touch code, and every change is cost- and security-checked in CI.*

## Deliverables
| | Hero promo | Deep-dive (recommended here) |
|---|---|---|
| Length | **~60–75s** | **~3–4 min** |
| Audio | Captions + music, **no voiceover** | **Voiceover** + captions |
| Use | LinkedIn / top of repo | "Watch the architecture walkthrough" |
| Plan | this file + `01_caption_script_hero.md` + `02_shot_list.md` | `04_deep_dive_plan.md` |

> For a platform project, the **deep-dive matters more than usual** — the value *is* the
> architecture and the trade-offs (see `ARCHITECTURE.md`'s design decisions). The hero gets the
> click; the deep-dive proves the seniority.

## The hero assets (no app — these instead)
1. **The dependency graph** — the Terragrunt `run-all` DAG across all layers and clouds (render the
   ASCII graphs in `ARCHITECTURE.md`, or `terragrunt graph-dependencies | dot`).
2. **A clean terminal** running `terragrunt run-all plan/apply` — the DAG executing in order.
3. **Cloud consoles** — Unity Catalog showing the governed catalogs/schemas/grants; the same model
   on AWS, Azure, GCP.
4. **CI artifacts** — a PR with the **Infracost** cost comment and **Checkov/tfsec** security checks
   passing (the "engineered, not hand-rolled" proof).

## 4 principles
1. **Credibility over flash.** This audience trusts a clean terminal and a real PR more than animation.
2. **Muted-friendly.** One sharp caption per beat; terminals are quiet by nature.
3. **The DAG is the hero shot.** "One command, correct order, three clouds" is the whole story — show the graph.
4. **Honest.** Don't fabricate a UI or a live multi-cloud apply you didn't run. Screenshots of real consoles/PRs are legitimate and expected.

## Structure — Hero (~70s, 6 scenes)
| # | Time | On screen | Caption |
|---|------|-----------|---------|
| 0 | 0–6s | Title card → flash the 3 cloud logos (AWS/Azure/GCP) + the Databricks/UC mark | *One control plane. Three clouds. Zero secrets in code.* |
| 1 | 6–20s | The Terragrunt **dependency DAG** (the graph render) | *Governed Databricks Unity Catalog — provisioned as code across AWS, Azure & GCP.* |
| 2 | 20–34s | Terminal: `terragrunt run-all plan` → the DAG resolves layer order across clouds | *One command builds the whole dependency graph — in the right order, automatically.* |
| 3 | 34–48s | Cloud consoles: UC catalogs/schemas/grants (AWS), quick cut to Azure & GCP equivalents | *The same governance model — natively on every cloud.* |
| 4 | 48–62s | A PR: **Infracost** cost comment + **Checkov/tfsec** green checks; `run_cmd` secrets-from-Secrets-Manager snippet | *Every change: cost-estimated and security-scanned in CI. Secrets never in code.* |
| 5 | 62–72s | End card: project name + value line + your name / GitHub | *Multi-cloud Unity Catalog governance — Terragrunt · OIDC · Delta Sharing* |

## Non-negotiables (the video must contain)
- The **dependency DAG** (the signature shot)
- The **`run-all`** command resolving order across clouds
- **Unity Catalog** governance visible in a real console
- The **CI proof**: Infracost (cost) + Checkov/tfsec (security)
- The **"secrets never in code"** point (a genuine differentiator)

## Pre-production checklist
- [ ] Render the DAG: the ASCII graphs already in `ARCHITECTURE.md`, **or** `terragrunt graph-dependencies | dot -Tpng > promo/dag.png` (clean, high-res).
- [ ] A **terminal recording** of `make plan` / `terragrunt run-all plan` (a plan is safe + free; an apply is optional). Use a large font, dark theme, no clutter.
- [ ] **Console screenshots** of Unity Catalog (catalogs/schemas/grants) on at least AWS (Azure/GCP if available). Redact account IDs / ARNs.
- [ ] A **PR** (real or a clean reconstruction) showing the Infracost comment and the Checkov/tfsec status checks — from the `dbx-validate` / `dbx-config-validate` workflows.
- [ ] Screen Studio / asciinema for the terminal; 16:9, retina.

## Honest do / don't
- **DO** use **real screenshots** of consoles and PRs — for IaC, that's the expected evidence, not a cop-out.
- **DO** show a **`plan`** (safe, free) rather than a live `apply` if cost/time is a concern — it still shows the DAG.
- **DON'T** invent a dashboard/UI for this project — it has none by design; faking one undercuts the credibility.
- **DON'T** show real secrets, ARNs, account IDs, or workspace URLs — redact everything sensitive.

## The one-line test
If a senior platform engineer watches **15 seconds on mute** and thinks *"one command, governed UC, three clouds, secrets handled right"* — the cut works.
