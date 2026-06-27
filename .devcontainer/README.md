# Dev container — the cloudless demo environment

The governance copilot (`scripts/`, `schema/`, `policy/`, and the domain JSON) is
entirely offline: no cloud, no credentials. This dev container gives a reviewer a
one-click way to run it.

## Use it

- **GitHub Codespaces:** *Code → Codespaces → Create codespace*. When it finishes
  building, run `make demo`.
- **VS Code locally:** *Dev Containers: Reopen in Container*, then `make demo`.

## What you get

- Python 3.11 with the dev dependencies (`pytest`, `ruff`, `jsonschema`).
- `conftest` (Open Policy Agent) for `make opa`, and `terraform` for `make fmt`.
- Ruff + Python + Terraform + OPA editor extensions, and `*_infra.json` /
  `*_grants.json` validated against [`schema/`](../schema/) as you type.

`make demo` runs the whole governance pipeline — validate → policy gate → report
sync → metrics → cost/carbon → drift summary → tests — in about 30 seconds,
proving the platform's governance story without provisioning anything.
