# Promo Capture — Recipe (how to produce the assets safely & cheaply)

This project has no app, so the "demo" is **capturing real artifacts**: the dependency graph, a
terminal plan, console screenshots, and a CI PR. None of this requires a costly live `apply` — a
**`plan`** is free and shows the DAG. Everything sensitive gets redacted.

## TL;DR
| Asset | How | Cost |
|---|---|---|
| Dependency DAG | `terragrunt graph-dependencies \| dot` or `ARCHITECTURE.md` graphs | free |
| Terminal | `make plan` / `terragrunt run-all plan` | free (no resources created) |
| UC consoles | screenshots of existing workspaces | free |
| CI proof | a real PR (Infracost + Checkov/tfsec) | free |

## 1. The dependency DAG (the hero still)
```
# high-res PNG of the run-all dependency graph
terragrunt graph-dependencies | dot -Tpng -Gbgcolor=transparent -Gdpi=200 > promo/dag.png
```
If Graphviz/`dot` isn't installed (`brew install graphviz`), the **ASCII dependency graphs already
in `ARCHITECTURE.md`** (AWS / Azure / GCP sections) are clean enough to screenshot directly.

## 2. The terminal plan (safe, free, shows the DAG)
```
make plan            # wraps terragrunt run-all plan across the stack
# or per cloud:
make plan-aws
make plan-azure
make plan-gcp
```
A `plan` **creates nothing** — it just resolves the dependency graph and previews changes, which is
exactly the "one command, correct order" story. Record it with a large font and a minimal prompt.

> Only run `make apply` if you specifically want a live "it really provisions" beat and you're happy
> with the cloud cost + teardown. The hero does **not** need it.

## 3. Unity Catalog console screenshots
From your existing Databricks workspaces, capture:
- **Catalog Explorer** — the governed catalogs and schemas (the domain model).
- **Grants** — the privilege assignments on a schema (the governance proof).
- **External locations / storage credentials** — the storage wiring.
- (Optional) the **Delta Sharing** shared catalog (GCP marketing → AWS metastore).

If you don't have all three clouds live, the **JSON domain definitions** (wired via
`jsondecode(file(...))`) plus an AWS console shot tell the same story honestly.

## 4. The CI proof (PR)
Open a PR that touches `infra/` so the workflows run:
- **Infracost** posts an AWS cost-breakdown comment.
- **Checkov** and **tfsec** run against `infra/` (from `dbx-validate.yml` / `dbx-config-validate.yml`).
Screenshot the PR conversation (cost comment) and the green checks. A previously merged PR works too.

## 5. Redaction pass (do this before publishing)
Platform footage leaks secrets easily. Before export, scrub every frame for:
- AWS **account IDs**, **ARNs**, IAM role names, `external_id`
- Databricks **workspace URLs** / host names, metastore IDs
- Azure subscription/tenant IDs, GCP project IDs
- Any value from **Secrets Manager**, tokens, or `terraform.tfstate` paths

Blur/box them in the edit. When in doubt, crop tighter.

## Honesty notes
- Real screenshots of real consoles and PRs are the **expected** evidence for IaC — not a shortcut.
- A `plan` (not `apply`) is a legitimate, honest way to show the DAG without spending money.
- Don't reconstruct a "fake" PR with invented numbers — use real Infracost/Checkov output (redacted).
