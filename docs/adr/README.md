# Architecture Decision Records

Each ADR captures one significant decision: the context that forced it, the choice
made, and the consequences accepted. They are immutable once `Accepted` — a
reversal is a new ADR that supersedes the old one, so the reasoning history stays
intact.

Format: a trimmed [MADR](https://adr.github.io/madr/). Template:
[`0000-template.md`](0000-template.md).

| ADR | Title | Status |
|---|---|---|
| [0001](0001-terragrunt-over-custom-orchestrator.md) | Terragrunt instead of a custom Python orchestrator | Accepted |
| [0002](0002-secrets-via-run-cmd-at-plan-time.md) | Fetch secrets via `run_cmd` at plan time, never store them | Accepted |
| [0003](0003-single-phase-iam-static-external-id.md) | Single-phase IAM with a static `external_id` | Accepted |
| [0004](0004-remote-state-s3-dynamodb.md) | Remote state in S3 with DynamoDB locking | Accepted |
| [0005](0005-generated-providers.md) | Generate provider/backend blocks, never commit them | Accepted |
| [0006](0006-zero-python-domain-governance.md) | Domain governance in JSON, consumed natively by Terragrunt | Accepted |
| [0007](0007-deterministic-governance-bounded-llm.md) | Deterministic governance gate with a bounded LLM on top | Accepted |
| [0008](0008-single-connectivity-toggle.md) | One `is_private_connection` toggle for the whole platform | Accepted |
| [0009](0009-cross-cloud-delta-sharing.md) | Cross-cloud Delta Sharing in native HCL | Accepted |
| [0010](0010-environments-as-file-mirrors.md) | `dev`/`prod` as file-for-file config mirrors | Accepted |

These records formalize the rationale narrated in [ARCHITECTURE.md](../../ARCHITECTURE.md);
that document remains the prose overview, the ADRs are the decision ledger.
