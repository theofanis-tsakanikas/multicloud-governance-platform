-- ============================================================================
-- GCP · 02 MEDALLION  ·  bronze → silver → gold for marketing
-- Governance proof: PII (user_email, ip_address) stays in SILVER, dropped in GOLD.
-- gold_marketing_by_region is then Delta-shared to the AWS metastore.
-- ============================================================================

-- ---- silver (KEEPS user_email + ip_address — governed) ----
CREATE OR REPLACE TABLE marketing_gcp.intelligence.web_clean AS
SELECT DISTINCT
  session_id, region,
  user_email, ip_address,               -- PII
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

-- Proof: DESCRIBE marketing_gcp.intelligence.gold_marketing_by_region;  -- no email / ip
