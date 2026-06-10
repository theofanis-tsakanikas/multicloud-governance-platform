# Hero Promo — Caption Script (exact words + timings)

**Target:** ~70s · captions + music, no voiceover · captions in English.
**Hero assets:** the Terragrunt **dependency DAG**, a **terminal** (`run-all plan`), **UC consoles**,
and a **PR** (Infracost + Checkov/tfsec). No app — this is a platform-eng cut (see `00_master_plan.md`).

Caption style: large, lower-third, white with a cyan accent on the key word, dark backing.
2.5–4s on screen. One line per beat. Terminals are quiet — let the captions do the narration.

---

### SCENE 0 — Hook (0:00–0:06)
- **Screen:** Title card on the dark gradient → 1.5s flash: AWS / Azure / GCP logos, then the Databricks Unity Catalog mark.
- **Caption (0:02):** `One control plane. Three clouds.`
- **Caption (0:04):** `Zero secrets in code.`
- **Music:** clean, "enterprise-tech" bed, low.

### SCENE 1 — The graph (0:06–0:20)
- **Screen:** The **dependency DAG** (`promo/dag.png` or the `ARCHITECTURE.md` graphs) — foundation → security → network → storage → integration → data platform, fanning across clouds.
- **Caption (0:08):** `Governed Databricks Unity Catalog —`
- **Caption (0:13):** `— provisioned as code across AWS, Azure & GCP.`

### SCENE 2 — One command (0:20–0:34)
- **Screen:** Clean terminal: `make plan` (or `terragrunt run-all plan`). The DAG resolves; modules report in dependency order. Speed-ramp the noise; hold on the ordered plan summary.
- **Caption (0:22):** `Terragrunt `dependency` blocks build the DAG…`
- **Caption (0:28):** `…so one command runs every layer, in the right order.`

### SCENE 3 — Same model, every cloud (0:34–0:48)
- **Screen:** Unity Catalog in a real console — catalogs, schemas, grants (AWS). Quick cuts to the Azure and GCP equivalents (or the JSON domain definitions wired via `jsondecode`).
- **Caption (0:36):** `The same governance model — natively on every cloud.`
- **Caption (0:42):** `Schemas, grants, external locations — defined in JSON, zero glue code.`

### SCENE 4 — Engineered in CI (0:48–0:62)
- **Screen:** A PR: the **Infracost** cost-breakdown comment, then green **Checkov / tfsec** checks. Cut to the `run_cmd` snippet that fetches secrets from AWS Secrets Manager at plan time.
- **Caption (0:50):** `Every change — cost-estimated and security-scanned in CI.`
- **Caption (0:57):** `Secrets fetched at plan time. Never in code, never in state.`

### SCENE 5 — Close (0:62–0:72)
- **Screen:** End card (dark). Project name + value line + your name / GitHub.
- **Caption (static):**
  > **Multi-Cloud Databricks Unity Catalog Governance**
  > Terragrunt DAG · OIDC CI · cross-cloud Delta Sharing
  > *<your name> — github.com/<you>*

---

## Caption master list (copy-paste ready)
```
1.  One control plane. Three clouds.
2.  Zero secrets in code.
3.  Governed Databricks Unity Catalog —
4.  — provisioned as code across AWS, Azure & GCP.
5.  Terragrunt dependency blocks build the DAG…
6.  …so one command runs every layer, in the right order.
7.  The same governance model — natively on every cloud.
8.  Schemas, grants, external locations — defined in JSON, zero glue code.
9.  Every change — cost-estimated and security-scanned in CI.
10. Secrets fetched at plan time. Never in code, never in state.
11. [End card] Multi-cloud Unity Catalog governance — Terragrunt · OIDC · Delta Sharing
```

## Notes
- **Delta Sharing** (GCP marketing catalog shared to the AWS metastore) is a strong extra beat — if
  you have a console shot of the shared catalog, add a 4s scene between 3 and 4 with caption:
  `Cross-cloud Delta Sharing — GCP data, governed from AWS.`
- Keep the terminal **legible**: large font, only the relevant lines, redact anything sensitive.
- The captions carry the story (terminals are silent) — make each one a complete, standalone claim.
