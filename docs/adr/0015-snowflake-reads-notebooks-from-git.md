# ADR-0015: Snowflake reads the demo notebooks from git, rather than having them uploaded

- **Status:** Accepted
- **Date:** 2026-07-11
- **Supersedes:** the `CREATE NOTEBOOK` half of `pipelines/snowflake/deploy_notebook.py`

## Context

The Snowflake demo (`pipelines/snowflake/governance_demo.ipynb` — zero-copy read of the
Databricks gold layer, plus role-based masking) needed to be *openable and runnable* in
Snowsight without anyone copy-pasting SQL on camera.

The first implementation pushed it in: `PUT` the `.ipynb` onto a stage, then

```sql
CREATE OR REPLACE NOTEBOOK "sales_aws"."demo"."governance_demo"
  FROM '@nb_stage' MAIN_FILE = 'governance_demo.ipynb'
  QUERY_WAREHOUSE = DEV_SALES_WH;
ALTER NOTEBOOK ... ADD LIVE VERSION FROM LAST;
```

It worked. It is also **on a deadline**. `CREATE NOTEBOOK` produces what Snowsight now labels
a *Legacy Notebook*, and Snowflake disables legacy-notebook **creation on 2026-09-01**. On that
date the pipeline step stops working — not gracefully, and not at a time of our choosing.

Two deeper problems were already visible before the deprecation notice:

- **It is a copy.** The notebook in the account is a *snapshot* of the notebook in the
  repository. They drift the moment someone edits either one. The whole platform argues that
  copies are the enemy of governance — and here it was making one, of its own proof.
- **It inverts the dependency.** The repository is the source of truth for every other artifact
  here (infrastructure, grants, policies, the medallion SQL). The notebook was the one thing
  that lived in the account and was *pushed* there by a script.

## Decision

**Invert the direction. Snowflake reads the notebook out of the repository.**

An `API INTEGRATION` authorises Snowflake to call the GitHub owner prefix, and a
`GIT REPOSITORY` object makes the repo readable from inside the account. A **Git-backed
Workspace** (Snowsight → Workspaces → *From Git repository*) then renders every `.ipynb` in the
repository as a native Workspace notebook, synced to `main`.

Both objects are Terraform, in `infra/snowflake/modules/global/git_repository/`, wired through
the same `snowflake_governance` layer that already translates the domain JSON into Snowflake
roles, grants and masking policies.

The repository is (or will be) **public**, so `git_credentials` is left unset — there is no
secret in this module to leak. The private-repo path is documented in `variables.tf` and needs
a read-only, repo-scoped PAT sourced the way every other credential here is: from AWS Secrets
Manager at apply time, never committed.

## Consequences

**Good**

- **Survives 2026-09-01.** Workspace notebooks are the supported object; legacy notebooks are not.
- **No copy, therefore no drift.** What a reviewer opens in Snowsight is byte-for-byte what is in
  `git log`. `git push` is the deploy.
- **The deploy script's job disappears.** `deploy_notebook.py` is retained only until the repo is
  public, then deleted — there is nothing left to deploy.
- **It is the same argument, applied to code.** The platform's claim about data is *read it where
  it lies, do not copy it*. This makes the claim true of the notebooks as well.
- **The integration is narrow.** `API_ALLOWED_PREFIXES` is scoped to one GitHub owner, not to
  GitHub. Every functional role gets `READ` on the repository; none gets write — pushes go
  through a PR, like every other change.

**Costs / risks**

- **One manual step, once.** Creating the Git-backed Workspace is a Snowsight action; there is no
  API for it today. The Terraform half (the integration the workspace selects) *is* automated, so
  the credential-bearing part is code and the pointing-at-it part is a click.
- **`snowflake_git_repository` is a preview resource.** The provider requires
  `preview_features_enabled = ["snowflake_git_repository_resource"]`, and a preview resource may
  change. Accepted: the alternative is raw `snowflake_execute` SQL with no state tracking at all.
- **`snowflake_api_integration` cannot express `git_https_api`.** The provider documents
  `snowflake_execute` as the path until it can, so the integration is raw SQL with an explicit
  `revert`. This is a provider gap, not a design choice, and it is commented as such.
- **Nothing works until the repo is public.** Both objects *create* fine against a private repo —
  Snowflake does not contact GitHub at create time — but `FETCH` will fail until visibility
  changes. This was accepted knowingly: the module applies today and starts serving the moment the
  repository is flipped, with no second apply.

## Alternatives considered

- **Keep `CREATE NOTEBOOK` and revisit in August.** Rejected: it is a known expiry date on a load-
  bearing demo, and the cost of fixing it later — under time pressure, possibly mid-recording — is
  strictly higher than fixing it now.
- **Migrate the existing notebook via the Snowsight "Migrate now" button.** Rejected: it moves the
  notebook into a *personal* workspace. It would survive the deprecation, but it would no longer be
  an artifact the platform provisions — it would be a thing that happens to exist in one person's
  account, which is precisely the property this repository exists to argue against.
- **Ship the demo as a Streamlit app instead.** Rejected: a notebook is the right medium for a
  demo whose entire point is *showing the query and its output side by side*. A Streamlit app hides
  the SQL, which is the evidence.
