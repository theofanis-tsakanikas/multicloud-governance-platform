# Testing — offline domain-config validation

This project provisions infrastructure with Terraform/Terragrunt and carries
**no Python application logic**. Its real "logic" lives in the per-domain
governance JSON under [`environments/dev/domains/`](../environments/dev/domains):
catalogs, schemas, volumes, external locations, and the Unity Catalog grants on
them. Those files are consumed by the `data_platform/dbx_governance`
Terragrunt configs and handed to Terraform as `jsonencode`'d inputs.

A mistake in that JSON does **not** fail fast:

- A mis-cased catalog `type` (`"Managed"` instead of `"MANAGED"`) is silently
  dropped by the HCL filter `[for c in catalogs : c if c.type == "MANAGED"]` —
  the catalog just never gets created.
- A grant that points at an object that doesn't exist only blows up part-way
  through `terragrunt apply`, after some resources already exist.
- A `domain_path` that is off by one `../` makes `file(...)` fail at parse time.

The test suite here is a **pre-flight check** that catches all of the above with
zero cloud access.

## What this is — and is NOT

- It is a **dev/test-only** validator + pytest suite.
- It is **not** part of the Terraform/Terragrunt apply path. `make apply-*`,
  the modules under `infra/`, and the Terragrunt wiring never import or invoke
  any Python. You can delete the entire Python footprint and the platform still
  deploys identically.
- It needs **no cloud credentials**. It only parses JSON and HCL text.
- The validator (`scripts/validate_domains.py`) is **stdlib-only** — `pytest`
  and `ruff` are needed solely to run the tests and linting.

## Components

| Path | Role |
|---|---|
| [`scripts/validate_domains.py`](../scripts/validate_domains.py) | The validator. Importable (`from validate_domains import validate_repo`) and a CLI. |
| [`tests/test_validate_domains.py`](../tests/test_validate_domains.py) | Pytest suite: real config passes; each rule fires on a crafted bad input. |
| [`requirements-dev.txt`](../requirements-dev.txt) | `pytest`, `ruff`. |
| [`pyproject.toml`](../pyproject.toml) | pytest + ruff config. |
| `.github/workflows/dbx-config-validate.yml` | No-creds CI job (complements the OIDC-gated `dbx-validate.yml`). |

## Running locally

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt

make validate-config     # run the validator against the repo (exit 1 on error)
make test                # ruff + pytest

# or directly:
python scripts/validate_domains.py            # human-readable report
python scripts/validate_domains.py --strict   # treat warnings as failures too
pytest -q
```

## What the validator checks

**Schema** (each file well-formed, matching how the HCL consumes it):

- `*_infra.json` / `*_grants.json` parse as JSON and conform to the discovered
  structure.
- Catalog `type` is **exactly** `"MANAGED"` or `"FEDERATED"` (case-sensitive) —
  a mis-cased/typo'd value is flagged because the HCL `MANAGED` filter would
  silently drop it.
- Federated catalogs declare a `connection_name`.
- `EXTERNAL` volumes declare `location_path` + `volume_path`.
- Grants have a `principal`, a non-empty `privileges` list, and a target object.

**Cross-file consistency** (the high-value checks):

- Every object a grant references (external location / catalog / schema /
  volume) **exists** in the corresponding `*_infra.json` — no dangling grants.
- Privilege names are valid Unity Catalog privileges **valid for that object
  type** (e.g. `READ_FILES` is valid on an external location but not a catalog).
- No duplicate catalog / schema / volume / external-location names within a
  domain.
- Group/principal names used consistently across the project — a name used only
  once is flagged as a likely typo (WARNING).

**Wiring** (the "easy to miss" step when adding a new domain):

- Every `file(...)` reference in each `dbx_governance/terragrunt.hcl` resolves
  to a JSON file that **exists** (`${get_terragrunt_dir()}` and
  `${local.domain_path}` are resolved offline).
- Every domain JSON file is referenced by some `terragrunt.hcl` (orphans →
  WARNING).

## Severity & exit codes

- **ERROR** → validator exits non-zero; CI fails.
- **WARNING** → reported, exit 0 by default. Use `--strict` to fail on warnings.

The current config has 2 known warnings: `crm_managers` and
`marketing_scientists` are each used in exactly one place. These are legitimate
single-domain groups, not typos — they demonstrate the singleton check working.

## Adding a new domain — validate before you apply

After following the README "Adding a new domain" steps (new `*_infra.json` /
`*_grants.json` and updating the `domain_path` / `file(...)` references in the
relevant `dbx_governance/terragrunt.hcl`), run:

```bash
make validate-config
```

This catches the dangling-grant, mis-cased-type, and missing-`domain_path`-file
mistakes before any cloud resources are touched.
