# ADR-0001: Terragrunt instead of a custom Python orchestrator

- **Status:** Accepted
- **Date:** 2025-05-31

## Context

The previous version of the platform shipped a 913-line Python orchestrator that
manually sequenced Terraform layers, passed outputs between them, injected
secrets, and resolved domain JSON into variables. It used YAML "blueprint" files
and a `cloud_generations.json` entropy file to track state. Every new layer or
cloud meant extending the orchestrator — bespoke code on the critical path of
every deploy, with no community support and its own bugs.

Ordering Terraform layers by their data dependencies and passing outputs between
them is exactly the problem [Terragrunt](https://terragrunt.gruntwork.io/) exists
to solve.

## Decision

Delete the orchestrator. Express every cross-layer dependency as a Terragrunt
`dependency {}` block; let `terragrunt run-all apply` build the DAG and execute
layers in topological order. Orchestration code: **zero lines**.

## Consequences

- Apply order is derived from declared dependencies, not hand-maintained — adding
  a layer is a new directory with a `dependency {}` block, no orchestrator edit.
- Output passing, remote-state reads, and parallelism come from a maintained,
  widely-understood tool instead of bespoke code.
- The team must know Terragrunt's model (`run-all`, `dependency`, `generate`).
- Single-layer applies (`make apply LAYER=...`) do **not** auto-apply
  dependencies; they read prior outputs from remote state, which must already
  exist. This is documented as a known gotcha.

## Alternatives considered

- **Keep/extend the Python orchestrator** — rejected: maintenance burden and
  reinvention of Terragrunt's core feature.
- **Terraform workspaces + a wrapper Makefile** — rejected: workspaces don't model
  inter-layer output dependencies; we'd rebuild orchestration in `make`.
- **Terramate / Terraspace** — viable, but Terragrunt's `dependency`/`generate`
  model fit the multi-cloud-layer shape most directly.
