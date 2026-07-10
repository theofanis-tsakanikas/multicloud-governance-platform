-- ============================================================================
-- GCP · 02 MEDALLION  ·  bronze → silver → gold for marketing
-- Governance proof: no PII is written here at all. Identities stay in the federated
-- source `marketing_bq_fed.web` (classified `pii`), queried in place, never copied.
-- gold_marketing_by_region is then Delta-shared to the AWS metastore.
-- ============================================================================

-- ---- silver (pseudonymous: visitor_id, never an identity) ----
CREATE OR REPLACE TABLE marketing_gcp.intelligence.web_clean AS
SELECT DISTINCT
  session_id, region,
  visitor_id,                           -- pseudonym; the identity behind it is in marketing_bq_fed.web
  campaign_id, CAST(spend AS DOUBLE) AS spend, event_date
FROM marketing_gcp.intelligence.web_raw
WHERE region IS NOT NULL;

-- ---- gold (NO PII) — the table shared to AWS ----
CREATE OR REPLACE TABLE marketing_gcp.intelligence.gold_marketing_by_region AS
SELECT region,
       COUNT(DISTINCT campaign_id) AS campaigns,
       COUNT(DISTINCT session_id)  AS sessions,
       ROUND(SUM(spend), 2)        AS marketing_spend
FROM marketing_gcp.intelligence.web_clean
GROUP BY region;

-- Proof: DESCRIBE marketing_gcp.intelligence.web_clean;  -- no email / ip, even in silver
