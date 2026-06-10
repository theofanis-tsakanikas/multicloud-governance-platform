# Deep-Dive Video — Plan (the architecture walkthrough)

**Length:** ~3–4 min · **Voiceover** + captions · for platform engineers / staff DEs / infra hiring.
Linked from the hero as "Watch the architecture walkthrough".

## Why the deep-dive matters MORE here
For a platform project, the architecture *is* the product. The hero gets the click; this is where
you prove the seniority — the design decisions, the trade-offs, and why they're right. Everything
below is grounded in `ARCHITECTURE.md`'s "Key design decisions" — narrate those, don't read them.

## Tone
Calm, senior, opinionated-but-justified. You're explaining choices to a peer who will challenge
them. Lead with the decision, then the *why*, then the alternative you rejected.

## Structure (≈7 sections)

### 1. Cold open (0:00–0:15)
- The DAG + the one-command thesis.
- **VO:** "This provisions governed Databricks Unity Catalog across AWS, Azure and GCP — with one command, no custom orchestrator, and no secrets in code. Here's how it's built."

### 2. The problem (0:15–0:45)
- **Screen:** a sketch — many clouds, many layers, manual ordering, secrets sprawl.
- **VO points:** multi-cloud data platforms drown in ordering and consistency problems: foundation before security before networking before storage before the data platform — times three clouds. People reach for a bespoke orchestrator or click-ops. Both rot.

### 3. Terragrunt over a custom orchestrator (0:45–1:25) — the core decision
- **Screen:** the `dependency {}` blocks; `run-all` resolving the DAG.
- **VO points:** instead of writing an orchestrator, **Terragrunt `dependency` blocks declare the edges** and `run-all` builds + executes the DAG in the correct order automatically. The graph is derived from the dependencies, not maintained by hand. (ARCHITECTURE.md §"Why Terragrunt over a custom orchestrator".)

### 4. Secrets never in code (1:25–2:00) — the security spine
- **Screen:** the `run_cmd` fetching from AWS Secrets Manager at plan time; an empty grep for secrets in state.
- **VO points:** secrets are fetched from **AWS Secrets Manager at plan time** via `run_cmd` — they never live in code, never in env-var injection, and **never land in Terraform state**. CI authenticates with **OIDC** (GitHub → AWS IAM role; Azure federated identity; GCP seeded from Secrets Manager) — **no long-lived credentials** anywhere.

### 5. Zero-Python domain governance (2:00–2:35)
- **Screen:** a domain JSON → `jsondecode(file(...))` → UC schemas/grants/external locations.
- **VO points:** adding a data domain is a **JSON edit**, not a code change. Schemas, grants and external locations are declared as data and wired into Terraform with `jsondecode` — no code-gen step, no drift between "what we meant" and "what we deployed". (ARCHITECTURE.md §"Domain governance — zero Python".)

### 6. Cross-cloud Delta Sharing + CI guardrails (2:35–3:20)
- **Screen:** the dual Databricks provider aliases sharing GCP → AWS; the PR with Infracost + Checkov/tfsec.
- **VO points:** the GCP marketing catalog is shared into the AWS metastore using **dual provider aliases and native HCL** — real cross-cloud governance, no export/copy. And every PR is gated: **Infracost** prices the AWS change, **Checkov + tfsec** scan `infra/`, and pre-commit enforces the same locally. Cost and security are part of code review, not an afterthought.

### 7. Close (3:20–3:50)
- **Screen:** end card + your name / GitHub.
- **VO points (honest framing):** "This is a reference implementation, not a fleet running in
  production — but every pattern in it is production-grade: DAG-ordered IaC, secret hygiene, OIDC,
  policy-as-code, cross-cloud sharing. It demonstrates multi-cloud platform engineering and the
  governance discipline that keeps a data platform safe as it scales." Stack: Terraform · Terragrunt
  · Databricks Unity Catalog · AWS/Azure/GCP · OIDC · Checkov/tfsec · Infracost.

## Production notes
- Lean on **`ARCHITECTURE.md`** for accuracy — quote the real decisions, keep numbers honest.
- A crisp **architecture diagram** per cloud (the layer table) anchors sections 2–5.
- **Redact** every account ID / ARN / workspace URL / secret (see `03_capture_recipe.md`).
- Pace screen to the VO; record terminal/console B-roll generously and trim to the narration.

## What NOT to do
- Don't fabricate a UI or a live multi-cloud apply you didn't run.
- Don't read HCL line-by-line — stay at "decision + why + rejected alternative".
- Don't overclaim production scale — it's a reference platform; say so, and let the engineering speak.
