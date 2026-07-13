# OPA / Conftest policy — the second opinion

[`governance.rego`](governance.rego) is an **independent re-implementation** of all
four gating rules from [`scripts/policy_analyzer.py`](../../scripts/policy_analyzer.py)
(`PUBLIC_PRINCIPAL`, `PII_BROAD_READ`, `PII_WRITE`, `SENSITIVE_ALL_PRIVILEGES`) in
[Rego](https://www.openpolicyagent.org/docs/latest/policy-language/), the
industry-standard policy language behind [Open Policy Agent](https://www.openpolicyagent.org/).

## Why a second engine

The Python analyzer is the source of truth and the CI gate. This Rego policy
double-checks it from the *outside*:

- **Defence in depth** — two independent engines must agree the access model is
  clean. A bug in one is unlikely to be mirrored in the other.
- **Portability proof** — the rules are not trapped in bespoke Python; they are
  expressible in the same OPA most platform teams already run, so they could be
  enforced at admission-control or gateway time too.

Both consume the analyzer's own output, `docs/governance/governance_context.json`,
so there is no separate input to maintain.

## Run it

```bash
# Clean committed config → ZERO denials (matches the analyzer's RESULT: PASS)
conftest test docs/governance/governance_context.json --policy policy/opa

# The unsafe fixture → denials across all four rules (proves the rules actually fire)
conftest test policy/opa/examples/violation_input.json --policy policy/opa
```

`make opa` runs both and is wired into `dbx-config-validate.yml`. A matching,
unexpired entry in `policy_exceptions.json` (which the analyzer records as an
`accepted` finding in the context) suppresses a denial here too — so the two
engines stay in lock-step on accepted risks.

## Offline cross-check

When `conftest` isn't installed, `tests/test_opa_consistency.py` re-derives the
same four rules in Python and asserts the Rego policy and the analyzer would
agree on both the clean config and the unsafe fixture — so the logic is verified
in the default test run even without the OPA binary.
