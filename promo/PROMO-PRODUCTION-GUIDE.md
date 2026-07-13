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
  deployed.** We rewind and watch what said no: one JSON contract that becomes infrastructure
  across **three clouds**, catalogs, grants, **three private paths with no public endpoint
  anywhere**, a medallion, a second engine reading the same gold file, and an AI that is allowed
  to describe governance but never to decide it. Then we land back on that same PR — now **green**,
  because someone wrote down a **reason** and a **date it expires**.
- **The shape — cold open + rewind + full circle:** open on the **red PR** (the stakes, instantly),
  **rewind** to the contract, walk **every stage**, then return to **that same PR, now green with a
  documented, expiring exception**. That callback is the whole thesis in one cut.

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
| Tests | **135**, infra-free, gating every push |
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
| First frame | **The red PR.** A GitHub check failing: `PII_BROAD_READ · HIGH`. Red ❌ |
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
| `01-pr-blocked` 🎥💤 | **GitHub PR** — add a grant of `SELECT` on `sales_rds_fed.crm` to `analysts` | the check turning **RED**: `PII_BROAD_READ · HIGH · schema:sales_rds_fed.crm`. Show the diff line that caused it | ~7s | tight on the red ❌ and the rule name |
| `02-the-contract` 🎥💤 | `environments/dev/domains/aws/sales_infra.json` + `sales_grants.json` | the JSON: catalogs, schemas, **`"classification": "pii"`**, and the grants block | ~6s | scroll from `classification` → the grant |
| `03-the-gate` 🎥💤 | terminal — `make policy-scan`, then `make opa` | the analyzer printing findings; then **OPA/Rego agreeing**. Say: *no cloud, no credentials* | ~7s | the HIGH line; then the OPA ✓ |
| `04-tests` 🎥💤 | terminal — `pytest -q` | **135 passed** | ~3s | the pass line |
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

Each row = one beat. Cut every clip on the music beat. **Total ≈ 90s.**
Note the arc: **beat 1 and beat 11 are the same pull request.**

| # | Time | Clip | On-screen | Caption (burn-in) | Motion / effect | Sound |
|--|--|--|--|--|--|--|
| 1 | 0:00–0:07 | `01-pr-blocked` | GitHub check **RED**, `PII_BROAD_READ · HIGH` | **Someone just gave analytics the customer PII.** → **The platform said no.** | punch-in on the red ❌; red flash | **BASS IMPACT** on the ❌ |
| 2 | 0:07–0:11 | rewind transition | the PR rewinds; JSON flows in | **It never reached a cloud.** → **It couldn't. Let's rewind.** | reverse-motion / rewind wipe | **rewind whoosh** |
| 3 | 0:11–0:18 | `02-the-contract` | the domain JSON | **One contract. Per domain.** → **Storage, grants, classification.** | scroll to `"classification": "pii"` | low rumble |
| 4 | 0:18–0:26 | `03-the-gate` + `04-tests` | analyzer → OPA → 135 passed | **A gate, not a report.** → **No cloud. No credentials.** → **And a second engine checks the first.** | snap on HIGH; snap on OPA ✓ | tick · tick · **ding** on 135 |
| 5 | 0:26–0:34 | `05-deploy` | the deploy inputs, then the green DAG | **One button. Three clouds.** → **Terraform · Terragrunt.** | speed-ramp the DAG greens | ding on ✅; rising ticks |
| 6 | 0:34–0:40 | `06-catalogs` | catalogs across 3 clouds | **Three clouds. One catalog.** | pan the tree | soft whoosh |
| 7 | 0:40–0:50 | `07-ncc-established` + `08-no-public-door` | 3× `ESTABLISHED` → RDS **No** → Azure **Disabled** | **Then we closed the front door.** → **No public address. Anywhere.** | 🥇 hold the 3 greens; box each toggle | **riser starts** |
| 8 | 0:50–0:58 | `09-one-query` | the three-cloud SQL + results | **One query. Three clouds.** → **Not one public endpoint in it.** | reveal the CTEs, then snap the grid | **riser resolves — impact** |
| 9 | 0:58–1:05 | `10-rejects` | the reject reasons | **The connection brings the truth.** → **Governance decides which of it is *true*.** | count-up to **220** | snap on 220 |
| 10 | 1:05–1:12 | `11-snowflake` + `12-genie` | Snowflake on the same file → Genie refusing | **One gold file. Two engines. Zero copies.** → **And an AI that knows what it isn't allowed to know.** | match-cut; 🥇 hold the refusal | whoosh; soft "no" tick |
| 11 | 1:12–1:24 | `13-pr-exception` (**payoff**) | the **same** PR — the exception, the **expiry**, then **GREEN** ✅ | **That PR?** → **It ships — with a reason, and a date it expires.** → **Governance isn't "no". It's "not without a reason, and not forever."** | callback: same shot as beat 1, now earned; box the `expires` field | **the payoff — resolve + ✅ ding** |
| 12 | 1:24–1:30 | `14-endcard` | title + handle | **Multi-Cloud Governance Platform** → **One contract. Three clouds. Two engines. Zero public endpoints.** → **Link in comments ↓** | logo settles, hold 3s | music resolves / outro |

---

## PART 4 — Every caption (copy-paste) + styling

```
1.  Someone just gave analytics the customer PII.
2.  The platform said no.
3.  It never reached a cloud.
4.  It couldn't. Let's rewind.
5.  One contract. Per domain.
6.  Storage, grants, classification.
7.  A gate, not a report.
8.  No cloud. No credentials.
9.  And a second engine checks the first.
10. One button. Three clouds.
11. Terraform · Terragrunt.
12. Three clouds. One catalog.
13. Then we closed the front door.
14. No public address. Anywhere.
15. One query. Three clouds.
16. Not one public endpoint in it.
17. The connection brings the truth.
18. Governance decides which of it is true.
19. One gold file. Two engines. Zero copies.
20. And an AI that knows what it isn't allowed to know.
21. That PR?
22. It ships — with a reason, and a date it expires.
23. Governance isn't "no".
24. It's "not without a reason, and not forever."
25. Multi-Cloud Governance Platform
26. One contract. Three clouds. Two engines. Zero public endpoints.
27. Link in comments ↓
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

- **0:00 — a single hard stab under the red ❌.** No build-up. The refusal *is* the impact.
- 0:07 — a **rewind sweep** as time pulls back.
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
- ✅ **The rewind** at 0:07 — the one signature transition.
- ✅ **Speed ramps** — the Terragrunt DAG going green; any scroll.
- ✅ **Kinetic numbers** — count-up / snap on **135 tests**, **220 rejected rows**, and nothing else.
- ✅ **Spotlight / box / arrow** — the red ❌, the three `ESTABLISHED` rows, `Publicly accessible: No`,
  `Public network access: Disabled`, the Genie refusal, the **`expires`** field.
- ✅ **Rounded corners + soft shadow** + a slight contrast grade.
- ✅ **Callback framing** — beat 11 reuses beat 1's exact shot. Same crop, same zoom. Non-negotiable.

### Avoid (cheapens it)

- ❌ Glitch / VHS / shake everywhere.
- ❌ Heavy transitions (spin, cube, page-curl) — the ONE rewind is the exception.
- ❌ Emojis / stickers / meme text, light leaks, lens flares, many fonts.
- ❌ **Claiming BigQuery has no public endpoint.** It does. Say *the connection* is private. The
  moment you overclaim, a technical viewer discounts everything else you said.

### Sound-design cue sheet

| Time | SFX | On what |
|--|--|--|
| **0:00** | **Bass impact / boom** | the red ❌ — the refusal |
| 0:07 | **Reverse whoosh / rewind** | the time-rewind transition |
| 0:18 / 0:22 | Faint "tick" ×2 | the analyzer HIGH; the OPA ✓ |
| 0:24 | **Ding** | **135 passed** |
| 0:26 | Ding + rising ticks | the deploy ✅; the DAG going green |
| **0:40** | **Riser (starts)** | under the three `ESTABLISHED` rows |
| **0:58** | **Riser resolves → impact** | the three-cloud query result |
| 1:02 | Snap | the count-up to **220** |
| 1:08 | Whoosh; soft "no" tick | Snowflake match-cut; the Genie refusal |
| **1:12** | **Resolve + ✅ ding** | the payoff — the PR goes green |
| 1:24 | Soft outro swell | CTA / logo settle |

> Search terms in CapCut SFX: "whoosh", "reverse", "rewind", "pop", "click", "impact", "boom",
> "riser", "ding", "notification", "alert".

---

## PART 7 — CapCut build order

1. **New project → canvas 1080×1440 (3:4).** Background: near-black `#0B0F14` (matches the banner).
2. **Import the `01`–`14` clips.** Remember `01-pr-blocked` and `13-pr-exception` are the **same
   screen in two states** — they must be framed identically.
3. **Rough cut:** trim each to its beat length from Part 3. Spine first — no captions yet. Lay the
   PR clip in **both** the opening and the payoff slot.
4. **Add the music.** Line the **stab up with the red ❌ (0:00)** and the **riser resolve with the
   three-cloud query (0:58)**. Nudge every cut onto a beat.
5. **The rewind (0:07):** reverse-motion transition into the contract.
6. **Speed ramps:** curve-speed the Terragrunt DAG greens.
7. **Framing:** scale each capture into the **upper 70%**, rounded corners + shadow, slight grade.
8. **Captions:** the 27 lines from Part 4, lower band, ≥1.2s, pop-in. Recolour the keywords.
9. **Kinetic numbers:** **135** and **220** snap or count up. Nothing else does.
10. **Highlights:** box the red ❌, the three `ESTABLISHED` rows, both `No`/`Disabled` toggles, the
    Genie refusal, and — most importantly — the **`expires`** field in the payoff.
11. **Sound design:** per the cue sheet. The bass impact, the rewind, and the payoff ding are what
    sell it.
12. **Transitions:** hard cuts everywhere; the ONE rewind at 0:07. Nothing else.
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
- [ ] Every number real: **135** tests, **220** rejected rows (not 249 — see the facts table), **3** NCC rules, **131** gateway sessions.
- [ ] **You did not claim BigQuery has no public endpoint.** Say *the connection* is private.
- [ ] Captions readable at thumbnail; burned in.
- [ ] **Poster/thumbnail = the red ❌.**
- [ ] Music royalty-free; no lyrics; stab on the ❌, resolve on the ✅.
- [ ] Length **≤ 90s**.
- [ ] Repo link in the **FIRST COMMENT**, not the body.

---

## Variant A — 60-second cut

Keep the cold open + payoff. Drop the catalogs, the rejects, and Snowflake.

| # | Time | Clip | Caption |
|--|--|--|--|
| 1 | 0:00–0:07 | `01-pr-blocked` | **Someone just gave analytics the customer PII.** → **The platform said no.** |
| 2 | 0:07–0:11 | rewind | **It never reached a cloud. Let's rewind.** |
| 3 | 0:11–0:19 | `02-the-contract` + `03-the-gate` | **One contract.** → **A gate, not a report — no cloud, no credentials.** |
| 4 | 0:19–0:26 | `05-deploy` | **One button. Three clouds.** |
| 5 | 0:26–0:36 | `07-ncc-established` + `08-no-public-door` | **No public address. Anywhere.** |
| 6 | 0:36–0:44 | `09-one-query` | **One query. Three clouds. Not one public endpoint in it.** |
| 7 | 0:44–0:50 | `12-genie` | **An AI that knows what it isn't allowed to know.** |
| 8 | 0:50–0:56 | `13-pr-exception` (payoff) | **That PR ships — with a reason, and a date it expires.** |
| 9 | 0:56–1:00 | `14-endcard` | **One contract. Three clouds. Two engines. Zero public endpoints. Link ↓** |

## Variant B — 30-second teaser

| # | Time | Clip | Caption |
|--|--|--|--|
| 1 | 0:00–0:06 | `01-pr-blocked` | **Someone gave analytics the customer PII. The platform said no — before it reached a cloud.** |
| 2 | 0:06–0:14 | `07-ncc-established` + `09-one-query` | **Three clouds. One query. Not one public endpoint in it.** |
| 3 | 0:14–0:20 | `12-genie` | **An AI that describes the governance — and is never allowed to decide it.** |
| 4 | 0:20–0:26 | `13-pr-exception` (payoff) | **Governance isn't "no". It's "not without a reason — and not forever."** |
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
