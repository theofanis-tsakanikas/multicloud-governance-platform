# ADR-0007: Deterministic governance gate with a bounded LLM on top

- **Status:** Accepted
- **Date:** 2025-06-19

## Context

The platform should be able to answer, provably, the questions an auditor or CTO
asks: *who can access what, where does PII live and who reads it, which risks are
open vs accepted?* The tempting modern answer is "point an LLM at the catalog and
ask". But an LLM in the decision path is non-deterministic, non-reproducible, and
unaccountable — unacceptable for a compliance control. Conversely, a pure CLI tool
is reproducible but hard for a non-engineer to interrogate.

## Decision

Split the layer by trust:

1. **`policy_analyzer.py` decides.** A deterministic, credential-free,
   rule-based least-privilege / PII analyzer is the source of truth. It gates CI
   (non-zero exit on any unacknowledged HIGH) and emits SARIF for the Security tab.
2. **`governance_report.py` documents.** It renders the analyzer's output as the
   EU-AI-Act / GDPR technical doc + a machine-readable grounding pack; CI asserts
   the committed docs match a fresh render.
3. **`genie_space.py` restates, in English.** A single cross-cloud Genie space
   answers questions **only** from the grounding pack — it cannot grant access,
   change policy, or read business data.

Deviations are not silenced in code: they live in `policy_exceptions.json` with a
justification, approver, and expiry, and an expired exception re-surfaces the risk.
An independent Rego/OPA policy re-derives the gating rules as a second opinion.

## Consequences

- Every governance verdict is reproducible from committed JSON with no LLM in the
  decision path — auditable on demand.
- The LLM is a convenience tier, bounded to facts the analyzer already proved.
- Two engines (Python + OPA) and a golden test corpus back the gate, so the rules
  are provably, not just presumably, correct.
- More moving parts than a single tool — mitigated by all of them being offline,
  tested, and CI-checked for sync.

## Alternatives considered

- **LLM-in-the-loop governance** — rejected: non-deterministic, unaccountable.
- **Analyzer only, no NL layer** — workable, but loses the "ask in English"
  accessibility for auditors; the bounded Genie tier adds that without ceding
  authority.
