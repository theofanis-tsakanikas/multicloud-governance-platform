# Live Setup — every credential, and **how** to get it

Follow this once, before the live recording. It is the "how", step by step.
When done, the [runbook](LIVE_RUN_RUNBOOK.md) is the deploy → run → teardown script.

## What you provide vs what Terraform creates

**Terraform auto-creates (do NOT create these by hand):** the Databricks SPN
secret (`databricks/spn/...`), the RDS password (`sales/rds-secret`), the Azure
SQL password + Key Vault secrets. You only provide the **seed** identities that
let the bootstrap authenticate the first time, plus GitHub secrets, `config.hcl`
values, a Snowflake account, and the state backend.

Everything below marked 🔑 is a value you'll paste somewhere.

---

## Step 1 · AWS remote-state backend (once, chicken-and-egg)
Terraform stores state in S3 + a DynamoDB lock table. They must exist **first**:
```bash
aws s3api create-bucket --bucket dbx-platform-tfstate-<YOUR_AWS_ACCOUNT_ID> \
  --region eu-central-1 --create-bucket-configuration LocationConstraint=eu-central-1
aws s3api put-bucket-versioning --bucket dbx-platform-tfstate-<YOUR_AWS_ACCOUNT_ID> \
  --versioning-configuration Status=Enabled
aws dynamodb create-table --table-name dbx-platform-tfstate-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH --billing-mode PAY_PER_REQUEST \
  --region eu-central-1
```

## Step 2 · GitHub OIDC role → 🔑 `DBX_DEPLOY_ROLE_ARN`
GitHub Actions assumes an AWS IAM role via OIDC (no long-lived keys).
1. **Create the OIDC provider** (once per AWS account):
   ```bash
   aws iam create-open-id-connect-provider \
     --url https://token.actions.githubusercontent.com \
     --client-id-list sts.amazonaws.com \
     --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
   ```
2. **Create the role** with a trust policy for your repo (`trust.json`):
   ```json
   { "Version": "2012-10-17", "Statement": [{
     "Effect": "Allow",
     "Principal": { "Federated": "arn:aws:iam::<ACCOUNT>:oidc-provider/token.actions.githubusercontent.com" },
     "Action": "sts:AssumeRoleWithWebIdentity",
     "Condition": { "StringLike": {
       "token.actions.githubusercontent.com:sub": "repo:theofanis-tsakanikas/multicloud-governance-platform:*" }}}]}
   ```
   ```bash
   aws iam create-role --role-name dbx-github-deploy --assume-role-policy-document file://trust.json
   aws iam attach-role-policy --role-name dbx-github-deploy --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
   # (tighten to Secrets Manager read + the services you deploy, for production)
   aws iam get-role --role-name dbx-github-deploy --query 'Role.Arn' --output text   # ← the ARN
   ```
   → 🔑 paste the ARN into GitHub secret `DBX_DEPLOY_ROLE_ARN`.

## Step 3 · Azure federated identity → 🔑 `AZURE_CLIENT_ID` / `AZURE_TENANT_ID` / `AZURE_SUBSCRIPTION_ID`
```bash
az login
az account show --query id -o tsv                 # ← AZURE_SUBSCRIPTION_ID
az account show --query tenantId -o tsv            # ← AZURE_TENANT_ID
az ad app create --display-name dbx-github-oidc    # note the appId
#   appId  ← AZURE_CLIENT_ID
# add a federated credential for GitHub Actions on that app:
az ad app federated-credential create --id <appId> --parameters '{
  "name":"github","issuer":"https://token.actions.githubusercontent.com",
  "subject":"repo:theofanis-tsakanikas/multicloud-governance-platform:ref:refs/heads/main",
  "audiences":["api://AzureADTokenExchange"]}'
# give the app Contributor on your subscription:
az role assignment create --assignee <appId> --role Contributor --scope /subscriptions/<SUBSCRIPTION_ID>
```

## Step 4 · The three SEED credentials (in AWS Secrets Manager)
These are the initial admin identities bootstrap uses before the platform's own
secrets exist. Each is a small JSON blob.

**4a · Databricks-AWS seed** → `databricks/bootstrap/seed_credentials`
- In the **Databricks Account console** (accounts.cloud.databricks.com) → *User
  management → Service principals* → create one → *Generate OAuth secret* →
  copy `client_id` + `secret`.
  ```bash
  aws secretsmanager create-secret --name databricks/bootstrap/seed_credentials \
    --secret-string '{"client_id":"<sp-client-id>","client_secret":"<sp-secret>"}' \
    --region eu-central-1
  ```

**4b · Databricks-GCP seed** → `gcp/bootstrap/seed_credentials`
- Same, but in the **GCP** account console (accounts.gcp.databricks.com) for
  `client_id`/`client_secret`; plus a **GCP service-account key** JSON (`provider_key`)
  for the Terraform `google` provider (create a SA in your GCP project with
  Owner/Editor for setup, download its JSON key).
  ```bash
  aws secretsmanager create-secret --name gcp/bootstrap/seed_credentials \
    --secret-string '{"client_id":"<gcp-sp-id>","client_secret":"<gcp-sp-secret>","provider_key":<paste-sa-key-json>}' \
    --region eu-central-1
  ```

**4c · Azure seed** → `azure/bootstrap/seed_credentials`
- Reuse the app from Step 3 (add a client secret: `az ad app credential reset --id <appId>`).
  Store the fields the azure foundation reads (check
  `environments/dev/bootstrap`/`azure/foundation` for exact keys — typically
  `client_id`, `client_secret`, `tenant_id`, `subscription_id`).
  ```bash
  aws secretsmanager create-secret --name azure/bootstrap/seed_credentials \
    --secret-string '{"client_id":"<appId>","client_secret":"<secret>","tenant_id":"<tenant>","subscription_id":"<sub>"}' \
    --region eu-central-1
  ```
> After creating each, run `aws secretsmanager describe-secret --secret-id <name>`
> to get its **full ARN** (with the random suffix) and paste it into `config.hcl`
> (`seed_credentials_arn`, `gcp_seed_secret_arn`, `azure_seed_secret_arn`).

## Step 5 · Snowflake account (you don't have one yet)
1. Sign up for a **free 30-day trial**: <https://signup.snowflake.com> — pick a
   cloud + region (e.g. AWS eu-central-1), Enterprise edition.
2. After login, your account identifier is `<ORG>-<ACCOUNT>` (Snowsight → bottom-left
   → *Account* → *View account details*). → 🔑 set in `config.hcl`:
   `snowflake_organization` and `snowflake_account`.
3. Create a local auth profile `~/.snowflake/config.toml`:
   ```toml
   [connections.default]
   account = "<ORG>-<ACCOUNT>"
   user = "<your-user>"
   password = "<your-password>"     # or set up key-pair auth
   role = "ACCOUNTADMIN"
   ```
4. The `snowflake_storage_integration_name` is created by a creds/bootstrap step;
   for the masking demo you can start with the defaults.

## Step 6 · `config.hcl` — the values that are **yours** (not the author's)
| Value | What it is | Where to find it |
|---|---|---|
| `aws_account_id` | your AWS account | `aws sts get-caller-identity --query Account` |
| `dbx_aws_account_id` | the AWS account Databricks runs in | Databricks account console |
| `dbx_account_id` | Databricks **AWS account UUID** | account console URL / *Account details* |
| `gcp_dbx_account_id`, `gcp_workspace_id`, `gcp_metastore_id` | Databricks **GCP** account/workspace/metastore IDs | GCP Databricks account console |
| `gcp_project_id`, `gcp_project_number` | your GCP project | `gcloud projects describe <id>` |
| `metastore_admins`, `admin_object_id` | your admin user/SP ids | Databricks / Azure AD |
| `seed_credentials_arn`, `gcp_seed_secret_arn`, `azure_seed_secret_arn` | the seed ARNs from Step 4 | `aws secretsmanager describe-secret` |
| `snowflake_organization`, `snowflake_account` | Step 5 | Snowsight account details |
| `deployment_id_aws/azure/gcp` | collision suffix | `openssl rand -hex 4` (rotate after any destroy) |

## Step 7 · Pipeline secrets (for the one-click data run)
For [`dbx-pipeline.yml`](../.github/workflows/dbx-pipeline.yml):
- 🔑 `DATABRICKS_HOST` — the **workspace** URL (not the account URL), e.g.
  `https://dbc-xxxx.cloud.databricks.com`.
- 🔑 `DATABRICKS_TOKEN` — Databricks workspace → *Settings → Developer → Access
  tokens → Generate* (a PAT), or an SPN token.
- 🔑 `DBX_WAREHOUSE_ID` — *SQL Warehouses → your warehouse →* copy the ID from the
  URL / *Connection details*.

## Set the GitHub secrets (any of the 🔑 above)
```bash
gh secret set DBX_DEPLOY_ROLE_ARN --body "arn:aws:iam::<acct>:role/dbx-github-deploy"
gh secret set AZURE_CLIENT_ID       --body "<appId>"
gh secret set AZURE_TENANT_ID       --body "<tenant>"
gh secret set AZURE_SUBSCRIPTION_ID --body "<sub>"
gh secret set DATABRICKS_HOST       --body "https://dbc-xxxx.cloud.databricks.com"
gh secret set DATABRICKS_TOKEN      --body "<pat>"
gh secret set DBX_WAREHOUSE_ID      --body "<warehouse-id>"
```

---

Now you're ready — go to [`LIVE_RUN_RUNBOOK.md`](LIVE_RUN_RUNBOOK.md) §2 (deploy) and
proceed. **Reminder:** everything here is real-money infra — deploy, record,
**destroy the same day**, then rotate `deployment_id_*`.

---

# Appendix · The same steps, in the UI (click-by-click)

Prefer the web consoles? Every step above has a point-and-click equivalent.

## Step 1 · State backend — AWS Console
- **S3 bucket:** Console → **S3** → *Create bucket* → name `dbx-platform-tfstate-<ACCOUNT_ID>`,
  Region *EU (Frankfurt) eu-central-1* → enable **Bucket Versioning** → *Create*.
- **Lock table:** Console → **DynamoDB** → *Create table* → name `dbx-platform-tfstate-lock`,
  Partition key `LockID` (**String**), *On-demand* capacity → *Create*.

## Step 2 · OIDC provider + role → `DBX_DEPLOY_ROLE_ARN` — AWS Console (IAM)
- **Provider:** IAM → **Identity providers** → *Add provider* → **OpenID Connect** →
  URL `https://token.actions.githubusercontent.com`, Audience `sts.amazonaws.com` → *Add*.
- **Role:** IAM → **Roles** → *Create role* → **Web identity** → choose the provider +
  audience → *Next* → attach **AdministratorAccess** (tighten later) → name
  `dbx-github-deploy` → *Create*. Open the role → **copy the ARN** (top of page).
  *(To restrict to your repo: edit the role's Trust relationship and add a
  `token.actions.githubusercontent.com:sub` condition = `repo:<owner>/<repo>:*`.)*

## Step 3 · Azure identity → `AZURE_*` — Azure Portal
- **IDs:** Portal → **Subscriptions** → copy **Subscription ID**. Portal →
  **Microsoft Entra ID** → *Overview* → copy **Tenant ID**.
- **App:** Entra ID → **App registrations** → *New registration* → name
  `dbx-github-oidc` → *Register* → copy **Application (client) ID**.
- **Federated credential:** the app → *Certificates & secrets* → **Federated
  credentials** → *Add credential* → scenario **GitHub Actions deploying…** →
  fill org/repo, branch `main` → *Add*.
- **Role:** Portal → **Subscriptions** → your sub → **Access control (IAM)** → *Add
  role assignment* → **Contributor** → assign to the `dbx-github-oidc` app → *Save*.

## Step 4 · Seed credentials — Databricks + AWS consoles
- **Databricks SP (AWS):** <https://accounts.cloud.databricks.com> → **User
  management → Service principals** → *Add* → open it → *Generate secret* → copy
  **Client ID** + **Secret**. (For GCP: same at <https://accounts.gcp.databricks.com>.)
- **GCP service-account key:** GCP Console → **IAM & Admin → Service Accounts** →
  *Create* → grant Owner/Editor (setup) → **Keys** → *Add key → JSON* → download.
- **Store each seed:** AWS Console → **Secrets Manager** → *Store a new secret* →
  **Other type** → **Plaintext** → paste the JSON (e.g.
  `{"client_id":"…","client_secret":"…"}`) → name it exactly
  `databricks/bootstrap/seed_credentials` (then `gcp/…`, `azure/…`) → *Store*.
  Open each stored secret → **copy the Secret ARN** → into `config.hcl`.

## Step 5 · Snowflake — Snowsight UI
- Sign up: <https://signup.snowflake.com> (AWS / eu-central-1, Enterprise).
- **Account id:** Snowsight → bottom-left **account menu** → *View account details*
  → copy `ORG-ACCOUNT` → into `config.hcl` (`snowflake_organization` / `_account`).
- Auth: create `~/.snowflake/config.toml` (or set key-pair auth in *Admin → Users*).

## Step 6 · Finding the `config.hcl` IDs in the UIs
- **AWS account id:** top-right account menu in the AWS Console.
- **Databricks account UUID:** the account console → top-right → *Account* (it's in
  the URL and account settings). Do this in **both** AWS and GCP account consoles.
- **GCP project id / number:** GCP Console → *Home / Dashboard* (Project info card).
- **Workspace / metastore ids (GCP):** GCP Databricks account console → *Workspaces*
  and *Data → Metastores*.

## Step 7 · Pipeline secrets — Databricks workspace UI
- **`DATABRICKS_HOST`:** your **workspace** URL from the browser address bar.
- **`DATABRICKS_TOKEN`:** workspace → top-right avatar → **Settings → Developer →
  Access tokens** → *Generate new token* → copy.
- **`DBX_WAREHOUSE_ID`:** workspace → **SQL → SQL Warehouses** → open your warehouse
  → the ID is in the URL and under *Connection details*.

## Setting the GitHub secrets — GitHub UI
`github.com/<owner>/<repo>` → **Settings → Secrets and variables → Actions** →
open each secret (the 4 empty ones already exist) → *Update* → paste value → *Save*.
For the pipeline ones, *New repository secret* → name (`DATABRICKS_HOST`, …) → value.
