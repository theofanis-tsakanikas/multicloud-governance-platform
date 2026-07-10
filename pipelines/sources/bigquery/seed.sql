-- ============================================================================
-- SIMULATED SOURCE SYSTEM · GCP · BigQuery (databricks-multicloud-platform)
--
-- Stands in for the analytics warehouse a marketing team owns (ADR-0014). The
-- governance platform never runs this: it is the "application" writing its own
-- tables, so that `marketing_bq_fed` — the Lakehouse Federation catalog — has
-- real rows to expose instead of empty datasets.
--
-- The two datasets already exist (storage/bigquery layer). This adds tables.
--
-- Deterministic: GENERATE_ARRAY and arithmetic on the row number. No RAND(), no
-- CURRENT_TIMESTAMP. Every run produces identical data; re-running is idempotent.
--
-- ── The two datasets are classified differently, and that is the point ──────
--
--   analytics  `internal`   session_id, market, visitor_id, campaign_id, spend
--                           pseudonymous. The medallion ingests THIS.
--
--   web        `pii`        session_id, user_email, ip_address, user_agent
--                           identities. The medallion NEVER reads this. It is
--                           queryable through the federated catalog, where the
--                           domain grants it to data_scientists alone — exactly
--                           as `sales_rds_fed.crm` works on AWS.
--
-- Joining them is possible, in place, from Databricks, by a principal who holds
-- both grants. That is the boundary doing its job rather than a wall.
--
-- ── The market asymmetry ───────────────────────────────────────────────────
-- The Netherlands is the cheapest market to reach (spend per session) and, in
-- the sales source, the highest order value. That pairing is what makes
-- `marketing_roi` in 03_executive.sql a recommendation instead of a flat chart.
--
--   Germany 90 · France 80 · Spain 60 · Italy 55 · Poland 40 · Netherlands 35
-- ============================================================================

-- ─────────────────────────────────────────────── analytics.sessions (no PII)
CREATE OR REPLACE TABLE analytics.sessions AS
WITH base AS (
  SELECT
    i,
    CASE
      WHEN MOD(i, 100) <  30 THEN 'Germany'
      WHEN MOD(i, 100) <  52 THEN 'France'
      WHEN MOD(i, 100) <  67 THEN 'Netherlands'
      WHEN MOD(i, 100) <  80 THEN 'Spain'
      WHEN MOD(i, 100) <  92 THEN 'Italy'
      ELSE                        'Poland'
    END AS market
  FROM UNNEST(GENERATE_ARRAY(1, 20000)) AS i
)
SELECT
  CONCAT('sess_', LPAD(CAST(i AS STRING), 7, '0'))              AS session_id,
  -- Every 50th session lost its market attribution: the medallion drops these.
  IF(MOD(i, 50) = 0, NULL, market)                              AS market,
  CONCAT('visitor_', LPAD(CAST(MOD(i * 37, 4000) AS STRING), 5, '0')) AS visitor_id,
  CONCAT('camp_', CAST(MOD(i, 30) AS STRING))                   AS campaign_id,
  ROUND(
    CASE market
      WHEN 'Germany'     THEN 90
      WHEN 'France'      THEN 80
      WHEN 'Spain'       THEN 60
      WHEN 'Italy'       THEN 55
      WHEN 'Poland'      THEN 40
      ELSE                    35   -- Netherlands: cheapest to reach
    END * (0.75 + MOD(i * 131, 50) / 100.0),
    2
  )                                                             AS spend,
  DATE_SUB(DATE '2026-07-10', INTERVAL MOD(i, 90) DAY)          AS event_date
FROM base;

-- ─────────────────────────────────────────────────────── web.visitors (PII)
--
-- This table is the reason `web` is classified `pii`. Nothing downstream reads
-- it: `marketing_gcp.intelligence` holds pseudonymous session data only, and the
-- medallion joins on `visitor_id`, never on an identity.
--
-- One row per distinct visitor_id in analytics.sessions.
CREATE OR REPLACE TABLE web.visitors AS
SELECT
  CONCAT('visitor_', LPAD(CAST(i AS STRING), 5, '0'))                       AS visitor_id,
  CONCAT('visitor', CAST(i AS STRING), '@example.com')                      AS user_email,   -- PII
  CONCAT('10.', CAST(MOD(i * 7, 255) AS STRING), '.',
                CAST(MOD(i * 13, 255) AS STRING), '.',
                CAST(MOD(i * 29, 254) + 1 AS STRING))                       AS ip_address,   -- PII
  CONCAT('Visitor ', CAST(i AS STRING))                                     AS full_name,    -- PII
  ['Chrome', 'Safari', 'Firefox', 'Edge'][OFFSET(MOD(i, 4))]                AS browser,
  DATE_ADD(DATE '2024-01-01', INTERVAL MOD(i * 7, 900) DAY)                 AS first_seen
FROM UNNEST(GENERATE_ARRAY(0, 3999)) AS i;
