# ADR-0006: Domain governance in JSON, consumed natively by Terragrunt

- **Status:** Accepted
- **Date:** 2025-05-31

## Context

Unity Catalog governance — catalogs, schemas, external locations, volumes, and the
grants on them — is the part of the platform that changes most often and is edited
by the most people. The previous version had Python parse domain definitions and
**generate** Terraform variables, a code-generation step that had to run before
every plan and was a source of drift between "what the JSON says" and "what got
applied".

## Decision

Define each domain as plain JSON (`<domain>_infra.json` + `<domain>_grants.json`)
and have Terragrunt read and transform it natively with `jsondecode(file(...))`,
filtering and re-encoding with `jsonencode()` into Terraform inputs. No Python, no
code generation, no intermediate files on the apply path.

```hcl
infra   = jsondecode(file("${get_terragrunt_dir()}/../../domains/aws/sales_infra.json"))
managed = [for c in local.infra.catalogs : c if c.type == "MANAGED"]
```

## Consequences

- Editing governance is editing data, not code — reviewable as a JSON diff.
- The JSON is the single source of truth; there is no generated artifact to drift.
- Adding a domain requires updating the `domain_path` locals in the relevant
  `dbx_governance/terragrunt.hcl` — the one easy-to-miss step, so it is validated.
- Additive keys (`classification`, `owner`) pass through `jsondecode`/`lookup`
  untouched, which is what lets the **offline** governance copilot
  ([ADR-0007](0007-deterministic-governance-bounded-llm.md)) reason about the same
  files without affecting any `apply`.
- A typo (mis-cased `type`, dangling grant) fails silently at apply time, so a
  dedicated offline validator (`scripts/validate_domains.py`) + a versioned JSON
  Schema (`schema/`) are the pre-flight guard.

## Alternatives considered

- **Keep Python codegen** — rejected: the drift and the extra build step were the
  problem.
- **Define governance directly in HCL** — rejected: less approachable for
  data-domain owners and not consumable by the offline governance tooling as data.
