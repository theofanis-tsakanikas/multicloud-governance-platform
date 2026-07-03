# 12. Package the policy gate as a standalone CLI + GitHub Action (govgate)

Date: 2026-07-03

## Status

Accepted

## Context

The deterministic least-privilege / PII analyzer (`policy_analyzer.py`) is the platform's best
idea: a credential-free gate that fails a PR on unsafe grants, cross-checked by an independent
OPA policy, and — since [ADR-0011](0011-snowflake-enforcement-backend.md) — covering *two*
enforcement backends from one contract. But it was reachable only by running this repo. Its
value to anyone else was zero, and a reviewer had to take the monorepo on faith rather than
run the gate against their own estate.

## Decision

Package the gate as an installable **CLI** and a reusable **GitHub Action**, with the monorepo
as its reference deployment.

- **CLI.** `pyproject.toml` gains a `[build-system]` + `[project.scripts] govgate =
  "policy_analyzer:main"` and declares the three flat modules the gate needs
  (`policy_analyzer`, `governance_model`, `validate_domains`) via `py-modules` +
  `package-dir = {"" = "scripts"}`. `pip install govgate` yields a `govgate` command with the
  existing flags (`--root`, `--strict`, `--format {text,json,sarif}`, `--output`,
  `--warn-expiring`). The stdlib-only design means **zero runtime dependencies**.
- **Action.** `actions/govgate/action.yml` is a composite Action that installs the gate from
  its own checkout and runs it, writing SARIF for code scanning and failing the job on an
  unacknowledged HIGH (or MEDIUM under `strict`). Anyone can add
  `uses: theofanis-tsakanikas/multicloud-governance-platform/actions/govgate@…` to their
  workflow and point it at their own `environments/<env>/domains`.
- **Non-invasive.** The existing flat `scripts/` layout, the `pythonpath = ["scripts"]` test
  setup, and all existing tests are untouched — packaging is additive.

## Consequences

**Benefits**
- The gate becomes a tool with potential users, not résumé decoration; the repo is its
  reference deployment, which is a stronger demonstration than a closed monorepo.
- "Works on Unity Catalog *and* Snowflake" (via the shared model) is a genuine differentiator
  the moment someone runs it against their own grants.

**Trade-offs**
- Discovery still assumes the `environments/<env>/domains/<cloud>/*_{infra,grants}.json`
  convention; adopting the tool means following (or adapting to) that layout. Making the
  discovery glob fully configurable is a deliberate follow-up, kept out of scope here to avoid
  destabilising the 100+ existing tests.
- The package name (`govgate`) and version now live in `pyproject.toml`; releases must be
  tagged for the Action's `@version` ref to be meaningful.
