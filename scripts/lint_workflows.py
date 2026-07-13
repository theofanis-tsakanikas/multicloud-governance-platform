#!/usr/bin/env python3
"""Assert that GitHub can actually read every workflow file.

This exists because `dbx-validate.yml` shipped with a YAML syntax error — two lines of a shell
heredoc at column 1 inside a `run: |` block, which terminates the block scalar — and stayed broken
from the commit that introduced it. GitHub's only signal was oblique: it could not parse the file, so
it could not read the workflow's `name`, so the README badge rendered the *file path* instead of the
name, and it recorded a failed run on every push. Twenty runs, twenty failures, and not one of them
executed a single step.

Meanwhile Checkov, tfsec, `terraform fmt`, `terragrunt validate` and the Infracost comment were
configured, believed in, and silently absent from every pull request the repository ever had.

A gate you think you have and do not is worse than no gate, because you stop looking at the thing it
was supposed to be watching.

Run by `dbx-config-validate.yml` (the credential-free job) and attacked by `scripts/gate_proof.py`.
"""

from __future__ import annotations

import glob

import yaml

WORKFLOWS = ".github/workflows/*.yml"


def main() -> int:
    paths = sorted(glob.glob(WORKFLOWS))
    if not paths:
        print(f"::error::no workflow files matched {WORKFLOWS}")
        return 1

    broken: list[tuple[str, str]] = []
    for path in paths:
        try:
            spec = yaml.safe_load(open(path))
        except yaml.YAMLError as exc:
            broken.append((path, str(exc).splitlines()[0]))
            continue
        # Parsing is necessary but not sufficient: a file that parses to a string, or to a mapping
        # with no `jobs`, is one GitHub will accept and never run.
        if not isinstance(spec, dict) or "jobs" not in spec:
            broken.append((path, "parses, but declares no jobs — GitHub will never run it"))
            continue
        print(f"  ok  {path}  ({spec.get('name', '<unnamed>')})")

    if not broken:
        print(f"\n  {len(paths)} workflow files, all readable by GitHub.")
        return 0

    print("\n::error::workflow files GitHub will not be able to run:")
    for path, why in broken:
        print(f"::error file={path}::{why}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
