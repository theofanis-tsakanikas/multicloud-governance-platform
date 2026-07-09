# Domain config JSON Schema

Versioned, machine-readable contracts for the per-domain governance config under
[`environments/*/domains/<cloud>/`](../environments/dev/domains/).

| Schema | Validates |
|---|---|
| [`domain.infra.schema.json`](domain.infra.schema.json) | `*_infra.json` — storage + Unity Catalog layout |
| [`domain.grants.schema.json`](domain.grants.schema.json) | `*_grants.json` — Unity Catalog RBAC |

Both are [JSON Schema Draft 2020-12](https://json-schema.org/draft/2020-12).

## Two layers, one contract

- **`scripts/validate_domains.py` is the runtime gate.** It does structural,
  cross-file (dangling-grant), object-type-aware privilege, and HCL-wiring checks
  that JSON Schema cannot express. It runs in pre-commit and CI and stays the
  source of truth.
- **These schemas are the versioned, IDE-facing contract.** They give editor
  autocomplete + inline validation while you write a domain file, and a stable
  `$id` other tooling can reference. When `jsonschema` is installed (it is a dev
  dependency, present in CI), `validate_domains.py` *additionally* validates each
  file against the matching schema and reports `SCHEMA_VALIDATION` findings — so
  the two layers are cross-checked against each other.

The schemas use `additionalProperties: true` on config objects on purpose: the
data `classification` / catalog `owner` keys are an additive convention and other
keys may be added without breaking older tooling (see
[ADR-0006](../docs/adr/0006-zero-python-domain-governance.md)).

## Editor autocomplete

[`.vscode/settings.json`](../.vscode/settings.json) maps the file globs to these
schemas, so VS Code validates `*_infra.json` / `*_grants.json` as you type with no
extra setup.

## Versioning

The title carries a `(v1)` marker and the `$id` is stable. A breaking change to
the config shape ships as a new file (`domain.infra.schema.v2.json`) so existing
pinned references keep resolving.
