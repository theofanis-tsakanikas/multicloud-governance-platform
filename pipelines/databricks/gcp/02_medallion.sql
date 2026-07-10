-- ============================================================================
-- GCP · 02 MEDALLION  ·  bronze → silver → gold for marketing
-- Governance proof: no PII is written here at all. Identities stay in the federated
-- source `marketing_bq_fed.web` (classified `pii`), queried in place, never copied.
-- gold_marketing_by_market is then Delta-shared to the AWS metastore.
-- ============================================================================

-- The serverless warehouse's default catalog is `hive_metastore`, and legacy
-- access is turned off on this account. Any DDL issued from such a session fails
-- with UC_HIVE_METASTORE_DISABLED_EXCEPTION — even when every name in the
-- statement is fully qualified, because the check is on the session, not on the
-- identifiers. A job's SQL task runs the whole file in one session, so one
-- statement fixes the file. Three-part names below still address other catalogs.
USE CATALOG marketing_gcp;

-- ---- silver (pseudonymous: visitor_id, never an identity) ----
CREATE OR REPLACE TABLE marketing_gcp.intelligence.web_clean AS
SELECT DISTINCT
  session_id, market,
  visitor_id,                           -- pseudonym; the identity behind it is in marketing_bq_fed.web
  campaign_id, CAST(spend AS DOUBLE) AS spend, event_date
FROM marketing_gcp.intelligence.web_raw
WHERE market IS NOT NULL;

-- ---- gold (NO PII) — the table shared to AWS ----
CREATE OR REPLACE TABLE marketing_gcp.intelligence.gold_marketing_by_market AS
SELECT market,
       COUNT(DISTINCT campaign_id) AS campaigns,
       COUNT(DISTINCT session_id)  AS sessions,
       ROUND(SUM(spend), 2)        AS marketing_spend
FROM marketing_gcp.intelligence.web_clean
GROUP BY market;

-- Proof: DESCRIBE marketing_gcp.intelligence.web_clean;  -- no email / ip, even in silver
