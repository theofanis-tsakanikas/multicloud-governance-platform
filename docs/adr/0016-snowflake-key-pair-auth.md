# ADR-0016: The Snowflake provider authenticates by key-pair, not password

- **Status:** Accepted
- **Date:** 2026-07-14
- **Supersedes:** the password half of the `snowflake_governance` provider config

## Context

The `snowflake_governance` layer authenticated the Terraform provider the simplest way that
works: `SNOWFLAKE_USER` + `SNOWFLAKE_PASSWORD`, injected as env vars at plan time. It applied
green for months.

Then the account enabled MFA, and the next apply died:

```
394508 (08004): Failed to authenticate: MFA with TOTP is required.
To authenticate, provide both your password and a current TOTP passcode.
```

This is not a misconfiguration to work around — it is the correct behaviour. A password plus a
one-time code from a phone is, by construction, something a non-interactive `terragrunt apply`
cannot supply. There is no env var for "the six digits currently on my authenticator." Snowflake
is also deprecating password-only sign-in for human users outright; an account that enforces MFA
today is a preview of every account tomorrow.

The failure was instructive in a second way. The *same* password credential is what a human uses
to log into Snowsight. Handing that credential to CI means CI authenticates as a person — and a
person is exactly what MFA exists to protect. The tool should not have been using a human's login
in the first place.

## Decision

**Switch the provider to key-pair (JWT) authentication.**

```hcl
provider "snowflake" {
  organization_name = "..."
  account_name      = "..."
  authenticator     = "SNOWFLAKE_JWT"   # private key from SNOWFLAKE_PRIVATE_KEY at plan time
}
```

An RSA key-pair is generated once. The **public** half is registered on the Terraform user
(`ALTER USER ... SET RSA_PUBLIC_KEY=...`) — it is not a secret and can be printed, committed to a
runbook, or pasted into a worksheet. The **private** half is stored as the `SNOWFLAKE_PRIVATE_KEY`
GitHub secret and read by the provider at plan time, exactly as every other credential here is
sourced at runtime and never committed. The deploy and destroy workflows inject it beside the
other `SNOWFLAKE_*` env vars.

Key-pair auth is the mechanism Snowflake documents for service accounts precisely because it is
**exempt from the interactive MFA factor**: possession of the private key *is* the second factor.
The JWT the driver signs with it is short-lived and per-request.

## Consequences

**Good**

- **Survives MFA — and survives password deprecation.** The apply no longer depends on a factor a
  machine cannot hold.
- **CI stops impersonating a human.** The pipeline authenticates as a service identity with its
  own key, not with the password a person types into Snowsight. Revoking one no longer breaks the
  other.
- **Still secrets-at-runtime.** No key material in code. The private key lives only in the secret
  store and in the runner's memory during a plan.
- **The public key is rotatable without redeploying.** `ALTER USER ... SET RSA_PUBLIC_KEY_2` allows
  a second key during rotation; the private secret is swapped, the old public key dropped. No code
  change.

**Costs / risks**

- **One manual step, once — registering the public key.** There is no bootstrap here that can set
  `RSA_PUBLIC_KEY` on the very user it authenticates as, so the public key is applied by hand (or
  by an admin) the first time, like the Git-backed Workspace in [ADR-0015](0015-snowflake-reads-notebooks-from-git.md).
  It is a one-line `ALTER USER`, and the public key is not sensitive.
- **The Python connectors needed the same treatment — done where the teardown depends on it.**
  `pipelines/snowflake/drop_demo.py` runs *inside the destroy* (it peels the demo external table off
  Terraform's stage, gotcha #11), so under an MFA account it would fail exactly where a destroy
  cannot afford to. It now prefers key-pair (`SNOWFLAKE_PRIVATE_KEY` → DER via `cryptography`) and
  falls back to password for a non-MFA fork. The two remaining scripts — `deploy_notebook.py` (slated
  for deletion once the repo is public, [ADR-0015](0015-snowflake-reads-notebooks-from-git.md)) and
  the one-shot `git_workspace.py` — still use password; neither runs in the deploy or destroy path,
  so they are honest follow-up, not a silent gap.
- **`SNOWFLAKE_PASSWORD` is retained, unused by Terraform.** It is left in the deploy/destroy env
  for the Python connector above; the provider ignores it once `authenticator = "SNOWFLAKE_JWT"`.

## Alternatives considered

- **Exempt the Terraform user from MFA via an authentication policy.** Rejected: it re-opens the
  hole MFA closed (a password that alone grants access), and it is a per-account carve-out that a
  forker would have to remember to recreate. Key-pair needs no exception — it is allowed *because*
  it is strong.
- **Use an interactive `externalbrowser`/OAuth authenticator.** Rejected outright: it requires a
  human at a browser, which is the one thing CI is not.
- **Keep password and disable MFA on the account.** Rejected: it fixes the demo by weakening the
  account, and it would be wrong the moment Snowflake enforces MFA for everyone regardless.
