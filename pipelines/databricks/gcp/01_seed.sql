-- ============================================================================
-- GCP · 01 SEED  ·  market-aligned raw marketing web data (pseudonymous)
-- Runs on the GCP workspace (marketing_gcp lives in the GCP metastore).
-- Shared market dimension: Germany · France · Netherlands · Spain · Italy · Poland
--
-- `marketing_gcp.intelligence` is classified `confidential`, NOT `pii`, so no
-- identity is written here. The identifying web data lives in the federated
-- source `marketing_bq_fed.web` (classified `pii`) and is queried in place —
-- the same boundary the AWS medallion draws against `sales_rds_fed.crm`.
-- ============================================================================
-- The serverless warehouse's default catalog is `hive_metastore`, and legacy
-- access is turned off on this account. Any DDL issued from such a session fails
-- with UC_HIVE_METASTORE_DISABLED_EXCEPTION — even when every name in the
-- statement is fully qualified, because the check is on the session, not on the
-- identifiers. A job's SQL task runs the whole file in one session, so one
-- statement fixes the file. Three-part names below still address other catalogs.
USE CATALOG marketing_gcp;

-- Read live from BigQuery through `marketing_bq_fed`. Only the `analytics` dataset
-- is touched: it is classified `internal` and holds pseudonymous sessions. The
-- `web` dataset is `pii` — emails, IPs, names — and the medallion never opens it.
-- Spend per session differs by market; the Netherlands is deliberately cheap to
-- reach and (see the sales seed) high in order value, which is what makes
-- `marketing_roi` in 03 a recommendation instead of a flat bar chart.
CREATE OR REPLACE TABLE marketing_gcp.intelligence.web_raw AS
SELECT
  s.session_id,
  s.market,
  s.visitor_id,                    -- pseudonym; the identity behind it is in web.visitors
  s.campaign_id,
  CAST(s.spend AS DOUBLE) AS spend,
  s.event_date
FROM marketing_bq_fed.analytics.sessions AS s;
