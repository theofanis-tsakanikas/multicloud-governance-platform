# Security Policy

This repository provisions data-governance infrastructure across three clouds. If you find a way to
break it, I want to know before anyone else does.

## Reporting a vulnerability

**Please do not open a public issue for a security problem.**

Use GitHub's [private vulnerability reporting](https://github.com/theofanis-tsakanikas/multicloud-governance-platform/security/advisories/new)
— it creates a private thread visible only to the maintainer.

I aim to acknowledge within **72 hours** and to have a fix or a stated position within **30 days**.
If a report is valid and you want credit, you get it.

## What is in scope

This is a **portfolio project**, not a hosted service. There is no production deployment and no user
data. What is worth reporting is anything that would harm somebody who deployed it:

- **A Terraform module that provisions something insecure by default** — an over-broad IAM policy, a
  security group open to `0.0.0.0/0`, an unencrypted bucket, a public endpoint that should not be one.
- **A hole in the policy gate** (`scripts/policy_analyzer.py`) — a grant that *should* be a HIGH
  finding and is not. The gate exists to fail a PR that hands someone access to PII; a way past it is
  the most valuable bug in this repo.
- **A CI workflow that leaks a secret or lets a fork run privileged actions.**
- **A committed credential.** (Every push is scanned by `gitleaks` over the full history, and the
  history is clean as of the last audit — but if I missed one, tell me.)
- **Anything in `docs/` that would mislead someone into an insecure deployment.**

## What is out of scope

- The **simulated source systems** (`pipelines/sources/`). They are deliberately seeded with weak,
  synthetic, obviously-fake data, and they exist so the pipeline has something to clean
  ([ADR-0014](docs/adr/0014-simulated-source-systems.md)). Their passwords are generated per-deploy
  and stored in a secret manager; their contents are not real.
- **Cloud identifiers in `environments/dev/config.hcl`** — the AWS account id, the Databricks account
  id, the GCP project id. These are not credentials. The AWS IAM trust policies are scoped to a
  Databricks-owned principal *and* require an `sts:ExternalId`, so knowing the role name and the
  account id grants nothing.

  **The Snowflake account locator is the exception, and it is not in this repository.** Unlike the
  others, an org + account resolve to `https://<org>-<account>.snowflakecomputing.com` — a working
  login page. An AWS account id grants nothing without a trust policy that names you; a Snowflake
  locator is a credential-stuffable endpoint. It comes from the environment
  (`SNOWFLAKE_ORGANIZATION` / `SNOWFLAKE_ACCOUNT_NAME`), set from a repository variable in CI.
  If you fork this and deploy the Snowflake layer, set your own.
- The **`prod/` tree**. It is a placeholder (`aws_account_id = "111111111111"`) and has never been
  applied.
- Findings that require an attacker to already hold valid credentials for one of the clouds.

## What this project does about its own security

Not a claim — the workflows are in `.github/workflows/` and you can read them:

| | |
|---|---|
| **Secret scanning** | `gitleaks.yml` — every push and PR, over the **full git history** |
| **Supply chain** | `sbom.yml` — SPDX SBOM (Syft) + CVE scan (Grype) → the Security tab, weekly |
| **IaC scanning** | `dbx-validate.yml` — Checkov + tfsec on every PR touching `infra/` |
| **The policy gate** | `dbx-config-validate.yml` — fails the PR on any unacknowledged HIGH finding, with **no cloud credentials at all** |
| **Cross-check** | The same gating rules re-implemented in OPA/Rego, run against the analyzer's output |
| **No long-lived keys** | Every cloud action authenticates by OIDC. There is no AWS key in any secret |
| **No secrets in code** | Every credential is fetched at plan time by shelling to the cloud's own CLI ([ADR-0002](docs/adr/0002-secrets-via-run-cmd-at-plan-time.md)) |

## Known limitations

Stated plainly, because a security file that only lists strengths is marketing:

- **The gate does not fail on MEDIUM findings.** Six `ALL_PRIVILEGES_NONADMIN` findings are open and
  CI is green. `--strict` would fail them. This is a deliberate posture for a demo repo, not an
  oversight — but if you deploy this, decide it for yourself.
- **The OPA cross-check re-implements 3 of the 4 gating rules** (`PII_WRITE` is missing) and consumes
  the analyzer's own output as its input. It is a cross-check, not an independent second engine.
- **A malformed `expires` date in `policy_exceptions.json` now fails closed.** An unparseable date
  is treated as already expired, so the finding it covers re-surfaces and the gate goes red (rather
  than the exception silently becoming permanent). There is still no JSON Schema on that file, so the
  *shape* of an entry is not validated — only the expiry is fail-safe.
- **In public connectivity mode the RDS instance is reachable from the internet.** The default
  connectivity is public (`PRIVATE_AWS=false`); in that mode the Postgres instance gets a public IP
  and its security group admits `0.0.0.0/0` on 5432, guarded only by a Secrets-Manager-generated
  password over synthetic data. Checkov does not flag this (the exposure is behind a `!var...`
  ternary it cannot resolve). Deploy in private mode, or restrict the ingress, for anything real.
- **Drift detection against a live metastore is not wired into CI.** A grant changed by hand in the
  Databricks UI will not be caught.
