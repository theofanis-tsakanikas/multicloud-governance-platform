# Snowflake ↔ Git — the repository as a first-class Snowflake object.
#
# WHY THIS EXISTS
#
# The Snowflake demo notebook used to be *pushed* into the account: stage the .ipynb, then
# CREATE NOTEBOOK over it (pipelines/snowflake/deploy_notebook.py). That creates a **legacy**
# notebook, and Snowflake disables legacy-notebook creation on 2026-09-01 — so the deploy
# would simply stop working. See ADR-0015.
#
# The replacement inverts the direction. Instead of the pipeline pushing a copy of the
# notebook into Snowflake, Snowflake **reads the notebook out of the repository**. A Git-backed
# Workspace (Snowsight → Workspaces → From Git repository) renders every .ipynb in the repo as
# a native Workspace notebook, git-synced. Nothing is copied, nothing drifts, and the artifact
# a reviewer opens in Snowflake is byte-for-byte the artifact in `git log`.
#
# That is the same claim the rest of this platform makes about data — read it where it lies,
# do not copy it — applied to code.
#
# TWO PROVIDER CONSTRAINTS, both load-bearing:
#
#   1. `snowflake_api_integration` does NOT support api_provider = git_https_api. The provider
#      documents `snowflake_execute` as the supported path until it does. Hence the raw SQL.
#   2. `snowflake_git_repository` is a PREVIEW resource — the caller's provider block must
#      list "snowflake_git_repository_resource" in preview_features_enabled, or the plan fails
#      with an unknown-resource error.
#
# ON A PRIVATE REPOSITORY
#
# Both objects below CREATE successfully against a private repo — Snowflake does not contact
# GitHub at create time. The FETCH is what needs read access. With `git_credentials` unset this
# module is the public-repository shape: it applies cleanly today and begins serving files the
# moment the repository is made public, with no further apply. That is deliberate — see the
# `git_credentials` note in variables.tf for the private-repo path.

# ── The trust: Snowflake may call this GitHub origin ────────────────────────
# CREATE OR REPLACE is safe here: an API integration holds no state of its own, and the
# git repository below is re-created with it if the prefix ever changes.
resource "snowflake_execute" "git_api_integration" {
  execute = join(" ", [
    "CREATE OR REPLACE API INTEGRATION ${var.api_integration_name}",
    "API_PROVIDER = git_https_api",
    "API_ALLOWED_PREFIXES = ('${var.allowed_prefix}')",
    "ENABLED = TRUE",
    "COMMENT = 'Lets Snowflake read the governance repository. Public repo: no credential.'",
  ])

  revert = "DROP API INTEGRATION IF EXISTS ${var.api_integration_name}"

  # Cheap, side-effect-free, and it proves the integration is actually resolvable.
  query = "SHOW API INTEGRATIONS LIKE '${var.api_integration_name}'"
}

# ── The repository, as an object the account can read ───────────────────────
#
# ⚠ ADR-0015 claimed this would apply cleanly against a still-private repository, on the
# reasoning that Snowflake does not contact GitHub at CREATE time. That was wrong, and the AWS
# deploy proved it:
#
#     093550 (22023): Failed to access the Git Repository. Operation 'clone' is not authorized.
#
# CREATE GIT REPOSITORY clones. Against a private repo with no credential, it fails — and it
# fails inside the AWS stack, where it has no business being the thing that stops a deploy.
#
# So the object is gated on the fact it depends on. `github_repo_is_public` is false today: the
# API INTEGRATION still applies (it is a trust declaration, it calls nothing, and it is all a
# Git-backed Workspace actually needs), and this waits. Flip the flag the day the repo is made
# public and `terragrunt apply` brings it up — that is the entire migration.
#
# The flag is not a feature toggle. It is a statement about the world, and it should be wrong
# for exactly as long as the world is.
resource "snowflake_git_repository" "governance" {
  count = var.github_repo_is_public ? 1 : 0

  name            = var.repository_name
  database        = var.database
  schema          = var.schema
  origin          = var.repo_origin
  api_integration = var.api_integration_name

  # Left unset on purpose: a public repository needs no credential. For a private repo,
  # set this to the fully-qualified name of a snowflake_secret_with_basic_authentication.
  git_credentials = var.git_credentials

  comment = "The governance repository. Snowflake reads the notebooks from git; nothing is uploaded."

  depends_on = [snowflake_execute.git_api_integration]
}

# ── Least privilege: readers may use the repo, they may not change it ───────
# Same vocabulary as every other grant in this platform — the functional roles read.
resource "snowflake_execute" "reader_grants" {
  for_each = var.github_repo_is_public ? toset(var.reader_roles) : toset([])

  execute = "GRANT READ ON GIT REPOSITORY ${var.database}.${var.schema}.${var.repository_name} TO ROLE ${each.value}"
  revert  = "REVOKE READ ON GIT REPOSITORY ${var.database}.${var.schema}.${var.repository_name} FROM ROLE ${each.value}"

  depends_on = [snowflake_git_repository.governance]
}
