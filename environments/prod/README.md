# prod environment

This tree mirrors `environments/dev/` file-for-file: every layer reads its values from
the nearest `config.hcl` (via `find_in_parent_folders`), so the **only** intentional
difference between dev and prod is this directory's [config.hcl](config.hcl).

What changes in prod:

| Concern | dev | prod |
|---|---|---|
| Cloud tenancy | Sandbox account/project/subscription | Dedicated production tenancy (fill the `TODO` placeholders in `config.hcl`) |
| Remote state keys | `environments/dev/...` | `environments/prod/...` (derived automatically from the path) |
| RDS instance class | `db.t3.micro` | `db.m5.large` |
| SQL warehouse | `2X-Small`, 10-min auto-stop | `Small`, 30-min auto-stop |
| Secrets Manager recovery window | 0 days (immediate delete) | 7 days |
| Resource names | base names | `-prod` suffixed |

Before the first apply:

1. Replace every `TODO` placeholder in `config.hcl` with the production tenancy
   identifiers (AWS account, Databricks account, Entra object IDs, seed-credential ARNs).
2. Run the bootstrap stacks for the production account (`environments/prod/bootstrap/...`).
3. Deploy per cloud exactly as in dev: `terragrunt run-all apply` from
   `environments/prod/<cloud>/`.

> Unity Catalog allows one metastore per region per Databricks account — production
> must therefore use its **own Databricks account** (or a different region), never the
> dev account. This is why the account identifiers are placeholders rather than copies.
