# Changelog

All notable changes to this project are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- **Snowflake — second enforcement backend (engine-agnostic governance).** The same domain JSON contract now compiles to Snowflake as well as Unity Catalog, proving the governance model is engine-agnostic (see [ADR-0011](docs/adr/0011-snowflake-enforcement-backend.md)):
  - `infra/snowflake/privilege_map.json` — a single shared translation contract (abstract/UC privilege → Snowflake privilege + scope), read by **both** the Snowflake Terraform and the Python consistency check
  - `scripts/snowflake_backend.py` — translates the shared `GovernanceModel` to Snowflake grants and proves **cross-backend access-equivalence** (independent per-engine read/write/admin classification; `--check` gates CI); 12 tests
  - `infra/snowflake/modules/global/*` + `infra/aws/modules/data_platform/snowflake_governance` + a Terragrunt leaf — functional-role RBAC, least-privilege grants (schema SELECT/MODIFY fanned out to ALL + FUTURE tables), tag-based masking from classification, row-access scaffolding, and a warehouse capped by a resource monitor. Official `snowflakedb/snowflake` v2.17.0 provider; `terraform validate` runs offline, credential-free (`tests/test_snowflake_terraform.py`)
- **`govgate` — the policy gate as an installable CLI + GitHub Action** ([ADR-0012](docs/adr/0012-govgate-packaging.md)): `pyproject.toml` build-system + console script; `actions/govgate/action.yml` composite Action (SARIF, fails on unacknowledged HIGH). The monorepo is the gate's reference deployment
- `snowflake` cost block in `cost_assumptions.json` + `cost_estimate.py` (credit-based warehouse cost); `make snowflake-check` / `snowflake-render` / `snowflake-validate`; a cross-backend consistency step in `dbx-config-validate.yml`
- Infracost job in `dbx-validate.yml` — posts an AWS infrastructure cost estimate as a PR comment on every pull request; scopes to `infra/aws/modules` and notes that Databricks, Azure, and GCP resources are out of Infracost's coverage
- Mermaid dependency graphs in `ARCHITECTURE.md` replacing the ASCII art — renders natively on GitHub; GCP cross-cloud edges (`bootstrap/aws/platform`, `aws/data_platform/dbx_governance`) are styled in blue
- `.github/ISSUE_TEMPLATE/bug_report.md` and `feature_request.md` issue templates
- `.github/PULL_REQUEST_TEMPLATE.md` pull request checklist
- `.github/dependabot.yml` configured for `github-actions` weekly updates
- README badge row (CI status, MIT license, Terraform, Terragrunt, Databricks, multi-cloud)
- README table of contents and "What this demonstrates" portfolio section
- gitleaks secret scanning: a pre-commit hook plus a CI workflow (`gitleaks.yml`, full git history); hardened `.gitignore` (secrets baseline)

### Changed
- Renamed the project to **Multi-Cloud Governance Platform** (repo `databricks-uc-multicloud-platform` → `multicloud-governance-platform`)

### Fixed
- All four GitHub Actions workflows (`dbx-validate.yml`, `dbx-deploy.yml`, `dbx-bootstrap.yml`, `dbx-destroy.yml`) had `WORKING_DIR: databricks-platform-v2` and monorepo-relative `working-directory` paths; corrected to repo-root-relative paths for standalone operation
- Infracost PR comment step made unconditionally soft-failing (`|| true`) so comment failures can never block a pull request

---

## [0.2.0] - 2026-05-30

### Added
- `CLAUDE.md` at repo root — operational reference covering apply order, secrets flow, domain governance pipeline, workflow trigger matrix, and seven known gotchas
- `ARCHITECTURE.md` — full dependency graphs for all three cloud stacks and the bootstrap sequence, key design decisions, domain model table, and annotated project structure

---

## [0.1.0] - 2026-05-26

### Added
- Terragrunt root configuration (`terragrunt.hcl`) with S3 remote state and DynamoDB locking
- Single-source config file at `environments/dev/config.hcl` covering all AWS, Azure, and GCP settings
- AWS stack: `foundation`, `security/iam`, `security/secrets_manager`, `network`, `storage/rds`, `storage/rds_schemas`, `integration`, `data_platform/dbx_creds`, `data_platform/dbx_governance`, `data_platform/dbx_rds_connector`, `data_platform/dbx_rds_grants`
- Azure stack: `foundation`, `security`, `network`, `storage/mssql`, `storage/mssql_schemas`, `integration`, `data_platform/dbx_creds`, `data_platform/dbx_governance`, `data_platform/dbx_mssql_connector`, `data_platform/dbx_mssql_grants`, `data_platform/dbx_workspace`, `data_platform/managed_warehouse`, `data_platform/uc_federation`
- GCP stack: `foundation`, `security`, `network`, `storage`, `integration`, `data_platform/dbx_creds`, `data_platform/dbx_governance`, `data_platform/dbx_bq_connector`, `data_platform/dbx_bq_grants`, `data_platform/dbx_workspace`, `data_platform/managed_warehouse`, `data_platform/uc_federation`, `data_platform/dbx_delta_sharing`
- Bootstrap modules for AWS (`aws_foundation`, `aws_platform`, `shared_config`, `shared_identities`, `shared_secrets`) and GCP (`gcp_foundation`, `gcp_platform`)
- Domain governance JSON for AWS (`sales_infra.json`, `sales_grants.json`), Azure (`supply_infra.json`, `supply_grants.json`), and GCP (`marketing_infra.json`, `marketing_grants.json`)
- Cloud-neutral Databricks modules: `catalog`, `external_location`, `federated_grants`
- Four GitHub Actions workflows: `dbx-validate.yml` (PR gate), `dbx-bootstrap.yml` (manual), `dbx-deploy.yml` (manual, multi-cloud), `dbx-destroy.yml` (manual with confirmation gate)
- Pre-commit configuration (`.pre-commit-config.yaml`) running `terraform fmt`, `terragrunt fmt`, Checkov, tfsec, and secret detection on every commit
- `Makefile` developer targets: `validate`, `fmt`, `bootstrap-{aws,gcp}`, `plan-{aws,azure,gcp}`, `apply-{aws,azure,gcp}`, `destroy-{aws,azure,gcp}`, `clean`
- MIT License

[Unreleased]: https://github.com/theofanis-tsakanikas/multicloud-governance-platform/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/theofanis-tsakanikas/multicloud-governance-platform/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/theofanis-tsakanikas/multicloud-governance-platform/releases/tag/v0.1.0
