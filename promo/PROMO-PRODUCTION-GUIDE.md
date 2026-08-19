# 🎬 Promo Video — Master Production Guide (Multi-Cloud Governance Platform)

**This is THE file. Follow it top to bottom.** Specs, which clips to record, the full timeline,
every caption, the music, the sound-design cue sheet, and the exact CapCut build order.

- **Editor:** CapCut · **Source:** your Screen Studio recordings in [`promo/`](.) and [`../images/`](../images)
- **Length:** **~90 seconds** (hard ceiling 90s) · a **60s** cut and a **30s** teaser are at the end
- **Ratio:** **3:4 portrait, 1080×1440** (matches your other LinkedIn videos) · backup 1:1 1080×1080
- **Captions:** **short & catchy** — a few words per line. Let the visuals carry the detail.
- **Audience:** data/platform engineers + engineering leaders + hiring managers
- **The story (one line):** a pull request tries to hand the analytics team a schema full of
  customer names, emails and phone numbers. **The platform refuses it — before anything is
  deployed.** Then we watch what said no: one JSON contract that becomes infrastructure
  across **three clouds**, catalogs, grants, **three private paths with no public endpoint
  anywhere**, a medallion, a second engine reading the same gold file, and an AI that is allowed
  to describe governance but never to decide it. Then we land back on that same PR — now **green**,
  because someone wrote down a **reason** and a **date it expires**.
- **The shape — a brand sting, then cold open + a black punchline + full circle:** open on a **~1.5s shield sting**
  (the amber shield takes a red PII attack head-on and it shatters against it — the shield holds), then
  hard-cut to the **red PR** (the stakes, made concrete). A **black punchline card**, then the contract, and walk **every
  stage**, then return to **that same PR, now green with a documented, expiring exception**. That
  callback is the whole thesis in one cut.

> **The hook is free.** The gate runs offline — no cloud, no credentials. Both the cold open and
> the payoff can be recorded **today**, on a torn-down stack, for **$0**.

> Workflow in one line: **record short, per-beat clips (zoom baked in) → assemble + caption +
> music + SFX in CapCut.** Do NOT drop a raw multi-minute recording into CapCut.

### ✅ Numbers & facts to keep honest (verified against the repo, 2026-07-12)

| Fact | Value |
|---|---|
| Clouds | **3** — AWS · Azure · GCP, from **one** `environments/dev/` tree |
| Databricks | **2 workspaces**, **1 Unity Catalog metastore** (one governance plane) |
| Second engine | **Snowflake** — reads the *same* S3 gold file, **zero copies** |
| The contract | **6 domain JSON files** — infra + grants + classification, per domain |
| The gate | `policy_analyzer.py` — **9 rules**, 4 of them HIGH; **fails the PR on any unacknowledged HIGH** |
| Cross-check | **OPA / Rego** re-implements **all 4** gating rules in a second engine, run against the analyzer's output in CI — both reach the same verdict. It reads the analyzer's own report as input, so it's a rule-logic cross-check, not a from-scratch second pipeline. |
| Exceptions | **time-bound**. An expired exception stops suppressing its finding and **fails CI again** |
| Live exceptions | 2 — `sales_rds_fed.crm` (expires **2026-12-31**), `marketing_bq_fed.web` (**2026-09-30**) |
| Offline | the whole gate runs with **no cloud and no credentials** |
| Tests | **137**, infra-free, gating every push |
| Infra | **Terraform via Terragrunt** — **87 modules**, **11 workflows**, one-button deploy / run / destroy |
| Decisions | **15 ADRs** — the decision ledger (`docs/adr/` also holds a template and a README) |
| Federated catalogs | `sales_rds_fed` (RDS) · `supply_sql_master` (Azure SQL) · `marketing_bq_fed` (BigQuery) |
| Cross-cloud share | `shared_gcp_delta_share` — GCP gold, Delta-Shared to AWS |
| Private mode | **3 NCC private-endpoint rules, all ESTABLISHED** |
| RDS | `publicly_accessible = **false**` — no public address at all |
| Azure SQL | `publicNetworkAccess = **Disabled**` — refuses the internet |
| BigQuery | reached through Google's **private API VIP** `199.36.153.8/30`, across an IPsec tunnel |
| Transit hubs | AWS `10.40.0.0/16` · Azure `10.10.0.0/16` · GCP `10.11.0.0/16` |
| Byte-level proof | **131** data-carrying gateway sessions, up to **1.9 MB**, all from private address space |
| Data quality | Silver removes **220** of 6,040 bronze rows. The rejects table reports **120** null markets, **61** refunds, **40** replays and **28** orphaned customers — the orphans are *kept* and relabelled `unknown`, not dropped, and one row trips two rules. Say "the gate refused 220 rows", not 249. |
| The AI | Genie — **read-only**, sees **4 governance tables and nothing else**. It runs as the *viewer*, so Unity Catalog's own grants cap what it can return (that is the platform default; the repo does not set it explicitly). |

> **The honest footnote, and say it:** BigQuery has **no** "disable public access" switch — it is a
> managed API. What is private there is the **connection**, not the disappearance of the public API
> surface. A CTO who knows that and hears you gloss it stops believing the rest.

---

## PART 1 — Specs & final export

| Setting | Value |
| --- | --- |
| Canvas | 1080 × 1440 (3:4 portrait) |
| Frame rate | 30 fps (60 if your captures are 60) |
| Codec | MP4 / H.264 |
| Length | **~90s** (hard ceiling 90s) |
| Layout | Screen capture **upper ~70%** (rounded corners + soft shadow), **caption band lower ~30%** |
| First frame | **The shield sting** (~1.5s): a red attack shatters against the amber shield; it holds. Then hard-cut to **the red PR** — a GitHub check failing, `PII_BROAD_READ · HIGH`, red ❌ |
| Captions | Burned in. Repo link goes in the **first comment**, not the post body |

---

## PART 2 — Clips to record / export (your "bricks")

Record each as its own short clip, **with zoom/framing set in Screen Studio**, and **2–3s of handle
on each end**. ✅ = already have it · 🎥 = to record · 💤 = needs no infrastructure (record any time)

> **The PR clip does double duty.** `01-pr-blocked` (red) and `12-pr-exception` (green) are the same
> screen, the same file, two states. Record them back-to-back in one sitting. **That reuse is what
> makes the full-circle land.**

| File | Source | What it must show | Length | Zoom / framing |
| --- | --- | --- | --- | --- |
| `00-shield-break` ✅💤 | **Kling** image-to-video from `promo/images/shield.png` | the amber shield; a red beam strikes it and shatters into red shards; the shield stays whole | ~1.5s (trim from the ~4s render) | centred; hard-cut out on the shatter |
| `01-pr-blocked` 🎥💤 | **GitHub PR** — add a grant of `SELECT` on `sales_rds_fed.crm` to `analysts` | the check turning **RED**: `PII_BROAD_READ · HIGH · schema:sales_rds_fed.crm`. Show the diff line that caused it | ~5.5s | tight on the red ❌ and the rule name |
| `02-the-contract` 🎥💤 | `environments/dev/domains/aws/sales_infra.json` + `sales_grants.json` | the JSON: catalogs, schemas, **`"classification": "pii"`**, and the grants block | ~6s | scroll from `classification` → the grant |
| `03-the-gate` 🎥💤 | terminal — `make policy-scan`, then `make opa` | the analyzer printing findings; then **OPA/Rego agreeing**. Say: *no cloud, no credentials* | ~7s | the HIGH line; then the OPA ✓ |
| `04-tests` 🎥💤 | terminal — `pytest -q` | **137 passed** | ~3s | the pass line |
| `05-deploy` 🎥 / ✅ | **GitHub Actions** — DBX Deploy | the workflow inputs (`aws/azure/gcp` · `public`/`private`), then the Terragrunt DAG applying green | ~8s | inputs → the green run |
| `06-catalogs` ✅ | Databricks **Catalog Explorer** — `images/aws`, `images/gcp` | the catalogs across three clouds under **one** metastore; the FOREIGN ones | ~6s | pan the catalog tree |
| `07-ncc-established` ✅ | Databricks **Account Console → Network → NCC** | **3 private-endpoint rules, all `ESTABLISHED`** — postgres, Azure SQL, googleapis | ~5s | 🥇 hold on the three green rows |
| `08-no-public-door` ✅ | AWS RDS console + Azure portal | RDS **`Publicly accessible: No`** → Azure SQL **`Public network access: Disabled`** | ~6s | box each toggle; whip between |
| `09-one-query` ✅ | Databricks — the **private-proof notebook**, cell 4 | one SQL statement joining **RDS + Azure SQL + BigQuery**, live | ~8s | the CTE names, then the result grid |
| `10-rejects` ✅ | `sales_aws.silver.sales_rejects` | the four reject reasons — null_market 120, refunds 61, replays 40, orphans 28 | ~5s | the reason/rows table |
| `11-snowflake` ✅ | `images/snowflake/` | Snowflake reading the **same S3 gold file** — zero copies | ~6s | the external table + `metadata$filename` |
| `12-genie` 🎥 | **Genie space** | the **refusal**: *"What is the CEO's home address?"* → *"I cannot answer that…"* | ~7s | 🥇 hold on the refusal text |
| `13-pr-exception` 🎥💤 | **the same PR** — add the entry to `policy_exceptions.json` | the exception with its **justification** and **`"expires": "2026-12-31"`**; the check turns **GREEN** ✅ | ~9s | the `expires` field, then the green ✓ |
| `14-endcard` 🎥 | build in CapCut | title + handle on near-black | ~4s | static |

**Optional B-roll:** the CloudWatch byte-proof (131 sessions, 1.9 MB — see
[`docs/evidence/`](../docs/evidence/private-connectivity.md)), the executive dashboard, the
Terragrunt destroy ("…and one button tears it all down — $0"), the transit-hub diagram from
[`images/prompts/09`](../images/prompts/09-three-clouds-private-hero.md).

---

## PART 3 — The master timeline (~90s, the heart of the edit)

Each row = one beat. Cut every clip on the music beat. **Total ≈ 90s** (the ~1.5s sting eats into the
old 7s opening, so the runtime is unchanged).
Note the arc: beat 0 is the brand sting; **beats 1 and 13 are the same pull request** — the full circle.
There is **no rewind**. Beat 2 is a **black punchline card** ("A report comes too late. A gate doesn't."),
and that is where the **music enters** and the explanation begins.

| # | Time | Clip | On-screen | Caption (burn-in) | Motion / effect | Sound |
|--|--|--|--|--|--|--|
| 0 | 0:00–0:015 | `00-shield-break` | the amber shield; a red attack shatters against it; it holds | *(no caption — let the break and the hit land)* | whoosh → shatter → shield flare | **whoosh + BASS IMPACT + glass shatter** (no "laser") |
| 1 | 0:015–0:06 | `01-pr-blocked` (`21.PR_red`) | GitHub check **RED**, `PII_BROAD_READ · HIGH` | **A grant exposed customer PII.** → **The platform said no.** | hard cut; punch-in on the red ❌ | low sub-hit on the cut |
| 2 | 0:06–0:11 | **BLACK CARD** (built in CapCut) | pure black | **A report comes too late.** → **A gate doesn't.** | text pop-in; hold ~2s on black | **music ENTERS here** (the swell) |
| 3 | 0:11–0:17 | contract JSON → catalog tree → Databricks+Snowflake | one file → three clouds → two engines | **One contract.** → **Three clouds.** → **Two engines.** | 3 quick frames, one per word | rising architectural pulse |
| 4 | 0:17–0:23 | `21.gate-attack` | the analyzer + OPA agreeing + 137 passed | **No cloud. No creds.** → **Cross-checked.** → **137 tests.** | snap on each | tick · tick · **ding** on 137 |
| 5 | 0:23–0:29 | `04.aws_deploy_final` | the deploy inputs, then the green DAG | **One button.** → **Terraform · Terragrunt.** | speed-ramp the DAG greens | ding on ✅; rising ticks |
| 6 | 0:29–0:35 | `09.databricks_querries` (catalog tree) | catalogs across 3 clouds, one metastore | **Managed. Federated. Shared.** | pan the tree | soft whoosh |
| 7 | 0:35–0:42 | `08.lineage_cross_cloud` | the auto cross-cloud lineage graph | **Nobody drew this.** → **It drew itself.** | reveal the graph | swell |
| 8 | 0:42–0:48 | `09.databricks_querries` (executive query) | the three-cloud SQL + result grid | **One query.** → **Three clouds fused.** | reveal the CTEs, then snap the grid | impact |
| 9 | 0:48–0:54 | `09.databricks_querries` (governance proof) + rejects | scan gold for PII → 0 rows; the rejects table | **PII in the gold?** → **Zero rows.** → **220 rows refused.** | snap to 0 rows; count-up to **220** | snap on 220 |
| 10 | 0:54–1:02 | `19.databricks_private` + `19.aws_private_connection` + `19.azure_private` (+ `19.cloudwatch_private`) | 3× `ESTABLISHED` · RDS **No** · Azure **Disabled** · private-IP packets | **The door? Shut.** → **Zero public endpoints.** | 🥇 hold the 3 greens; box each toggle | **riser resolves — impact** |
| 11 | 1:02–1:09 | `14.snowflake_queries` | `metadata$filename` (same S3 key) → masking by role | **Same file. Two engines.** → **Zero copies.** → **Masked by role.** | match-cut; admin email → analyst `***MASKED***` | whoosh |
| 12 | 1:09–1:15 | `20.genie` | Genie refusing the CEO-address question | **An AI copilot.** → **It knows its limits.** | 🥇 hold on the refusal text | soft "no" tick |
| 13 | 1:15–1:25 | `21.gate-green` (**payoff**) | the **same** PR — the exception, the **`expires`**, then **GREEN** ✅ | **That same PR?** → **Now it ships.** → **A reason. An expiry.** | callback: same crop/zoom as beat 1; box the `expires` field | **the payoff — resolve + ✅ ding** |
| 14 | 1:25–1:30 | `14-endcard` (built in CapCut) | title + tagline | **Governance isn't "no". "Not without a reason. Not forever."** → **Multi-Cloud Governance Platform** → **Link in comments ↓** | logo settles, hold 3s | music resolves / outro |

---

## PART 4 — Every caption (copy-paste) + styling

_Beat 0 (the shield sting) carries **no caption** — the visual break and the bass hit are the hook. The
numbered captions below start at the red PR._

```
1.  A grant exposed customer PII.
2.  The platform said no.
3.  A report comes too late.
4.  A gate doesn't.
5.  One contract.
6.  Three clouds.
7.  Two engines.
8.  No cloud. No creds.
9.  Cross-checked.
10. 137 tests.
11. One button.
12. Terraform · Terragrunt.
13. Managed. Federated. Shared.
14. Nobody drew this.
15. It drew itself.
16. One query.
17. Three clouds fused.
18. PII in the gold?
19. Zero rows.
20. 220 rows refused.
21. The door? Shut.
22. Zero public endpoints.
23. Same file. Two engines.
24. Zero copies.
25. Masked by role.
26. An AI copilot.
27. It knows its limits.
28. That same PR?
29. Now it ships.
30. A reason. An expiry.
31. Governance isn't "no".
32. "Not without a reason. Not forever."
33. Multi-Cloud Governance Platform
34. Link in comments ↓
```

**Styling — near-black + amber (match the banner):**

- Font: clean sans (Inter / Helvetica / SF), weight **700–800**, **large** (readable at thumbnail).
- Colours: white base; accent keywords **amber `#F59E0B`**; danger words **red `#F87171`**;
  safe/allowed words **green `#34D399`**.
- One short line at a time, lower third. On screen **≥1.2s** each. Subtle pop/scale-in.
- **Recolour these:** `PII` / `HIGH` / `said no` (red) · `Zero public endpoints` / `Disabled` /
  `ESTABLISHED` / `expires` (green) · `Terraform` / `Terragrunt` / `Databricks` / `Snowflake` /
  `Unity Catalog` (amber).

---

## PART 5 — Music

A **restrained, confident build** — not an action trailer. This is a *governance* film: it should
feel **assured**, not frantic. Opens with a hard stab (the refusal), settles into a steady
architectural pulse, **peaks at 0:58** (three clouds in one query), and resolves warmly under the
payoff.

**Sync map:**

- **0:00 — a single hard stab under the shield shatter (~0:015).** No build-up. The break *is* the
  impact. The hard-cut to the red PR lands a beat later on a low sub-hit.
- **0:06 — the music enters on the black punchline card** (the swell). The breath before the explanation.
- 0:11–0:40 — a steady, architectural pulse. Restrained. Let the visuals speak.
- **0:40 — a riser starts** under the private-path beat (three greens, two closed doors).
- **0:58 — the riser resolves** on the three-cloud query. This is the crest of the film.
- 0:58–1:12 — sustained, warmer.
- **1:12 — the payoff.** The music softens and *resolves* on the green ✅ — this beat should feel
  like relief, not triumph. The point is not that we won; it is that the system worked.
- 1:24–1:30 — outro under the CTA.

**Vibe / search terms:** "minimal tech," "corporate innovation," "ambient build," "cinematic
confidence," ~95–115 BPM. **No lyrics.** Sources: **Uppbeat** · **YouTube Audio Library** ·
**Pixabay Music** · Epidemic Sound / Artlist (paid).

---

## PART 6 — Effects guide + sound-design cue sheet

### Use these (tasteful, pro). Skip the rest.

- ✅ **Sound design** — the biggest multiplier (cue sheet below).
- ✅ **Hard cuts on the beat** — the strongest "effect" there is.
- ✅ **The black punchline card** at 0:06 — the breath where the music enters, before the explanation.
- ✅ **Speed ramps** — the Terragrunt DAG going green; any scroll.
- ✅ **Kinetic numbers** — count-up / snap on **137 tests**, **220 rejected rows**, and nothing else.
- ✅ **Spotlight / box / arrow** — the red ❌, the three `ESTABLISHED` rows, `Publicly accessible: No`,
  `Public network access: Disabled`, the Genie refusal, the **`expires`** field.
- ✅ **Rounded corners + soft shadow** + a slight contrast grade.
- ✅ **Callback framing** — beat 11 reuses beat 1's exact shot. Same crop, same zoom. Non-negotiable.

### Avoid (cheapens it)

- ❌ Glitch / VHS / shake everywhere.
- ❌ Heavy transitions (spin, cube, page-curl). Hard cuts only.
- ❌ Emojis / stickers / meme text, light leaks, lens flares, many fonts.
- ❌ **Claiming BigQuery has no public endpoint.** It does. Say *the connection* is private. The
  moment you overclaim, a technical viewer discounts everything else you said.

### Sound-design cue sheet

| Time | SFX | On what |
|--|--|--|
| **0:00** | **whoosh → bass impact → glass shatter** (no "laser") | the shield shatter — the red attack breaking against the shield |
| 0:015 | Low sub-hit | the hard cut to the red PR |
| 0:06 | **Soft swell (music in)** | the black punchline card |
| 0:18 / 0:22 | Faint "tick" ×2 | the analyzer HIGH; the OPA ✓ |
| 0:24 | **Ding** | **137 passed** |
| 0:26 | Ding + rising ticks | the deploy ✅; the DAG going green |
| **0:40** | **Riser (starts)** | under the three `ESTABLISHED` rows |
| **0:58** | **Riser resolves → impact** | the three-cloud query result |
| 1:02 | Snap | the count-up to **220** |
| 1:08 | Whoosh; soft "no" tick | Snowflake match-cut; the Genie refusal |
| **1:12** | **Resolve + ✅ ding** | the payoff — the PR goes green |
| 1:24 | Soft outro swell | CTA / logo settle |

> Search terms in CapCut SFX: "whoosh", "energy surge", "glass shatter", "pop", "click", "impact", "boom",
> "riser", "ding", "notification", "alert".

---

## PART 7 — CapCut build order

1. **New project → canvas 1080×1440 (3:4).** Background: near-black `#0B0F14` (matches the banner).
2. **Import the `00`–`14` clips.** `00-shield-break` is the opening sting. Remember `01-pr-blocked` and
   `13-pr-exception` are the **same screen in two states** — they must be framed identically.
3. **Rough cut:** trim each to its beat length from Part 3. Spine first — no captions yet. Lay the
   **shield sting first (~1.5s)**, hard-cut to the red PR, and lay the PR clip in **both** the opening
   and the payoff slot.
4. **Add the music.** Line the **stab up with the shield shatter (~0:015)** and the **riser resolve with
   the three-cloud query (0:58)**. Nudge every cut onto a beat.
5. **The black punchline card (0:06):** hold ~2s on black, the music enters, then hard-cut to the contract.
6. **Speed ramps:** curve-speed the Terragrunt DAG greens.
7. **Framing:** scale each capture into the **upper 70%**, rounded corners + shadow, slight grade.
8. **Captions:** the 27 lines from Part 4, lower band, ≥1.2s, pop-in. Recolour the keywords.
9. **Kinetic numbers:** **137** and **220** snap or count up. Nothing else does.
10. **Highlights:** box the red ❌, the three `ESTABLISHED` rows, both `No`/`Disabled` toggles, the
    Genie refusal, and — most importantly — the **`expires`** field in the payoff.
11. **Sound design:** per the cue sheet. The bass impact, the music entry on the black card, and the payoff ding are what
    sell it.
12. **Transitions:** hard cuts everywhere. Nothing fancy.
13. **End card:** title + handle, held 3s.
14. **Watch it muted, full size.** If a caption is unreadable at thumbnail, fix it.
    **Poster/thumbnail = the red ❌ with `PII_BROAD_READ · HIGH`.**
15. **Export:** 1080×1440, H.264, 30/60 fps.

---

## PART 8 — Pre-flight & publish checklist

- [ ] **No secrets on screen** — no SPN client secret, no AWS account id in an ARN you didn't mean to
      show, no Databricks workspace URL you'd rather not publish, no `.env`. Scrub or crop.
- [ ] **Beat 1 and beat 11 are framed identically.** Same crop, same zoom. The callback dies otherwise.
- [ ] The `expires` date is **visible and legible** in the payoff. It is the whole argument.
- [ ] Every number real: **137** tests, **220** rejected rows (not 249 — see the facts table), **3** NCC rules, **131** gateway sessions.
- [ ] **You did not claim BigQuery has no public endpoint.** Say *the connection* is private.
- [ ] Captions readable at thumbnail; burned in.
- [ ] **Poster/thumbnail = the red ❌** (the shield mid-shatter is a striking alternative, but the red ❌ with `PII_BROAD_READ · HIGH` is the more specific hook).
- [ ] Music royalty-free; no lyrics; stab on the ❌, resolve on the ✅.
- [ ] Length **≤ 90s**.
- [ ] Repo link in the **FIRST COMMENT**, not the body.

---

## Variant A — 60-second cut

Keep the cold open + payoff. Drop the catalogs, the rejects, and Snowflake.

| # | Time | Clip | Caption |
|--|--|--|--|
| 0 | 0:00–0:015 | `00-shield-break` | *(no caption — the break + the bass hit)* |
| 1 | 0:015–0:07 | `01-pr-blocked` | **A grant exposed customer PII.** → **The platform said no.** |
| 2 | 0:06–0:11 | BLACK CARD | **A report comes too late. A gate doesn't.** |
| 3 | 0:11–0:19 | `02-the-contract` + `03-the-gate` | **One contract.** → **A gate, not a report — no cloud, no credentials.** |
| 4 | 0:19–0:26 | `05-deploy` | **One button. Three clouds.** |
| 5 | 0:26–0:36 | `07-ncc-established` + `08-no-public-door` | **No public address. Anywhere.** |
| 6 | 0:36–0:44 | `09-one-query` | **One query. Three clouds. Zero public endpoints.** |
| 7 | 0:44–0:50 | `12-genie` | **An AI that knows its limits.** |
| 8 | 0:50–0:56 | `13-pr-exception` (payoff) | **That PR ships — with a reason that expires.** |
| 9 | 0:56–1:00 | `14-endcard` | **One contract. Three clouds. Two engines. Zero public endpoints. Link ↓** |

## Variant B — 30-second teaser

| # | Time | Clip | Caption |
|--|--|--|--|
| 0 | 0:00–0:015 | `00-shield-break` | *(no caption — the break + the bass hit)* |
| 1 | 0:015–0:06 | `01-pr-blocked` | **A grant exposed customer PII. Blocked before it hit a cloud.** |
| 2 | 0:06–0:14 | `07-ncc-established` + `09-one-query` | **Three clouds. One query. Zero public endpoints.** |
| 3 | 0:14–0:20 | `12-genie` | **An AI that describes the governance — and is never allowed to decide it.** |
| 4 | 0:20–0:26 | `13-pr-exception` (payoff) | **Governance isn't "no". Not without a reason. Not forever.** |
| 5 | 0:26–0:30 | `14-endcard` | **Multi-Cloud Governance Platform — breakdown in the comments ↓** |

---

## Appendix — how to record beats 1 and 13 (the whole film hangs on them)

Both run **offline**. No cloud, no credentials, **$0**. Do them in one sitting, same window, same zoom.

**Beat 1 — the refusal (red):**

1. Branch. In `environments/dev/domains/aws/sales_grants.json`, grant `analysts` `SELECT` on the
   `crm` schema — the one carrying `"classification": "pii"`.
2. Push, open the PR. `dbx-config-validate` runs the analyzer with **no credentials at all**.
3. It fails: **`PII_BROAD_READ · HIGH · schema:sales_rds_fed.crm`**. **Record the red ❌.**
4. Also record the **diff line** that caused it — one line of JSON. That is the villain of the film.

**Beat 13 — the exception (green):**

5. On the *same* PR, add an entry to `environments/dev/policy_exceptions.json`: the rule, the
   object, a **real justification**, and an **`expires`** date.
6. Push. The check turns **GREEN** ✅. **Record it — same framing as beat 1.**
7. **Hold on the `expires` field.** That is the line the whole video is written to deliver:

> *An expired exception stops suppressing its finding, and CI fails again. That is not a bug —
> it is the point. Nobody gets to grant themselves PII access and forget about it.*

**Then throw the branch away.** It was a film set, not a change.
