# Hero Promo — Shot List (capture this, in this order)

No app to record — you're assembling a **graph render, a terminal capture, console screenshots, and
a PR**. Most of these are stills or short screen captures; the edit gives them motion (push-ins,
reveals). This is the normal, credible way to demo platform/IaC work.

## Stage 0 — Setup (before any capture)
1. **Render the DAG** (the signature shot):
   ```
   terragrunt graph-dependencies | dot -Tpng -Gbgcolor=transparent > promo/dag.png
   ```
   …or screenshot the clean ASCII graphs already in `ARCHITECTURE.md` (AWS/Azure/GCP sections).
2. **Terminal recording** of a **plan** (safe + free):
   ```
   make plan            # or: terragrunt run-all plan
   ```
   Use a large font, dark theme, minimal prompt. asciinema or Screen Studio both work.
3. **Console screenshots:** Unity Catalog catalogs/schemas/grants on AWS (Azure/GCP if available).
   **Redact** account IDs, ARNs, workspace URLs.
4. **A PR** with the **Infracost** comment + **Checkov/tfsec** checks (from `dbx-validate` /
   `dbx-config-validate`). A real merged PR is ideal; a clean reconstruction is acceptable if redacted.
5. Screen Studio: 16:9, retina, clean menu bar.

---

## Clips / stills to capture (in this order)

### SHOT A — The dependency DAG (the hero still)
- **What:** `promo/dag.png` (or the ARCHITECTURE.md graph). A slow push-in across the layers as
  they fan out to the three clouds.
- **Form:** high-res still → animate in the edit (Ken Burns).
- **Use:** ~12s.

### SHOT B — `run-all plan` terminal
- **What:** The plan command resolving the DAG; modules reporting in dependency order; the ordered
  plan summary at the end.
- **Form:** screen capture; **speed-ramp** the verbose middle, hold on the resolved order.
- **Use:** ~14s.

### SHOT C — Unity Catalog consoles
- **What:** Catalogs → schemas → grants on AWS; quick cuts to Azure & GCP (or the JSON domain
  definitions wired via `jsondecode(file(...))`).
- **Form:** screenshots or short captures; redact sensitive IDs.
- **Use:** ~14s.

### SHOT D — CI proof (PR)
- **What:** The PR conversation: the **Infracost** cost-breakdown comment, the green **Checkov /
  tfsec** status checks. Then the `run_cmd`/Secrets-Manager snippet.
- **Form:** screenshots; push-in on the cost number and the green checks.
- **Use:** ~14s.

### SHOT E — Delta Sharing (OPTIONAL strong beat)
- **What:** The GCP marketing catalog shared into the AWS metastore (console), or the native-HCL
  Delta Sharing resource. Adds a memorable cross-cloud beat.
- **Use:** ~4s.

### Title + End cards
- Built in the editor. Text from `01_caption_script_hero.md` (scenes 0 and 5).

---

## Assembly order (in the editor) = final scenes
`Title → SHOT A → SHOT B → SHOT C (+ SHOT E) → SHOT D → End card`
Map to the script: 0 → 1 → 2 → 3 → 4 → 5.

---

## Screen Studio / edit tips
- The **DAG** is your thumbnail and your hook — make it crisp and high-res.
- For stills (graph, consoles, PR), use **slow push-ins / reveals** so it doesn't feel like a slideshow.
- **Speed-ramp** verbose terminal output; **hold** on the meaningful summary lines.
- **Redact** every account ID / ARN / URL / secret — do a frame-by-frame pass before publishing.
- **Music:** restrained, "enterprise tech", low. This cut earns trust, not adrenaline.
- Export **1080p MP4, 30–60fps**.

## Final QC before you publish
- [ ] The **DAG** reads clearly as "one command, correct order, three clouds".
- [ ] **No** secrets / ARNs / account IDs / workspace URLs anywhere on screen.
- [ ] The CI shot clearly shows **cost** (Infracost) **and** **security** (Checkov/tfsec).
- [ ] No invented UI — every frame is a real artifact.
- [ ] Ends with a clear "what is this + who made it" card.
