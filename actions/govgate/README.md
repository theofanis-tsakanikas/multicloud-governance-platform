# govgate — the governance gate as a reusable Action

The deterministic least-privilege / PII analyzer that gates *this* repo, extracted so **any**
repo can run it against its own domain grants. The monorepo is the gate's reference
deployment; this Action and the `govgate` CLI are the same code, packaged.

## As a GitHub Action

```yaml
- uses: theofanis-tsakanikas/multicloud-governance-platform/actions/govgate@main
  with:
    root: .          # repo root containing environments/<env>/domains
    strict: "false"  # also gate on MEDIUM findings
- uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: govgate.sarif
```

The gate fails the job on any unacknowledged **HIGH** finding (PII broad-read, public
principal on sensitive data, ALL_PRIVILEGES on PII, …). Documented, time-bound exceptions in
`environments/<env>/policy_exceptions.json` downgrade a finding from gating to reported.

## As a CLI

```bash
pip install govgate            # from this repo (build-system in pyproject.toml)
govgate --root . --format sarif --output govgate.sarif
govgate --root . --strict      # exit 1 on HIGH (or MEDIUM under --strict)
```

## Why it is engine-agnostic

The gate reasons over the vendor-neutral governance model (`scripts/governance_model.py`),
so a single run covers **both** enforcement backends — Unity Catalog *and* Snowflake — before
either applies. See [ADR-0011](../../docs/adr/0011-snowflake-enforcement-backend.md) and
`scripts/snowflake_backend.py` for the cross-backend equivalence proof.
