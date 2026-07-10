-- ============================================================================
-- GCP · 01 SEED  ·  region-aligned raw marketing web data (pseudonymous)
-- Runs on the GCP workspace (marketing_gcp lives in the GCP metastore).
-- Shared region dimension: EU-North · EU-South · EU-East · EU-West
--
-- `marketing_gcp.intelligence` is classified `confidential`, NOT `pii`, so no
-- identity is written here. The identifying web data lives in the federated
-- source `marketing_bq_fed.web` (classified `pii`) and is queried in place —
-- the same boundary the AWS medallion draws against `sales_rds_fed.crm`.
-- ============================================================================
CREATE OR REPLACE TABLE marketing_gcp.intelligence.web_raw AS
SELECT
  concat('sess_', lpad(cast(id AS STRING), 7, '0'))                                     AS session_id,
  element_at(array('EU-North','EU-South','EU-East','EU-West'), cast(rand()*4 AS INT)+1) AS region,
  concat('visitor_', lpad(cast(rand()*99999 AS INT) AS STRING, 5, '0'))                 AS visitor_id,   -- pseudonym, not an identity
  concat('camp_', cast(rand()*30 AS INT))                                               AS campaign_id,
  round(rand()*90 + 1, 2)                                                               AS spend,
  date_add(current_date(), -cast(rand()*90 AS INT))                                     AS event_date
FROM range(20000) AS t(id);
