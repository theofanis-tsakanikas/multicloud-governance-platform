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
-- Spend per session differs by market. The Netherlands is deliberately cheap to
-- reach and (see the sales seed) high in order value: that pairing is what makes
-- `marketing_roi` in 03 an actual recommendation instead of a flat bar chart.
CREATE OR REPLACE TABLE marketing_gcp.intelligence.web_raw AS
WITH base AS (
  SELECT
    id,
    CASE
      WHEN id % 100 <  30 THEN 'Germany'
      WHEN id % 100 <  52 THEN 'France'
      WHEN id % 100 <  67 THEN 'Netherlands'
      WHEN id % 100 <  80 THEN 'Spain'
      WHEN id % 100 <  92 THEN 'Italy'
      ELSE                     'Poland'
    END AS market
  FROM range(20000) AS t(id)
)
SELECT
  concat('sess_', lpad(cast(id AS STRING), 7, '0'))                       AS session_id,
  market,
  concat('visitor_', lpad(cast(rand()*99999 AS INT) AS STRING, 5, '0'))   AS visitor_id,   -- pseudonym, not an identity
  concat('camp_', cast(rand()*30 AS INT))                                 AS campaign_id,
  round(CASE market
          WHEN 'Germany'     THEN 90
          WHEN 'France'      THEN 80
          WHEN 'Spain'       THEN 60
          WHEN 'Italy'       THEN 55
          WHEN 'Poland'      THEN 40
          ELSE                    35   -- Netherlands: cheapest to reach
        END * (0.7 + rand()*0.6), 2)                                      AS spend,
  date_add(current_date(), -cast(rand()*90 AS INT))                       AS event_date
FROM base;
