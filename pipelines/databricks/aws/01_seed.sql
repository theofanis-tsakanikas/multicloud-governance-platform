-- ============================================================================
-- AWS · 01 SEED  ·  ingest from the federated source; no PII enters the lakehouse
-- Runs on the AWS workspace (sales_aws + supplies_azure governance live here).
-- Shared market dimension (the cross-cloud join key, NOT a cloud region):
--   Germany · France · Netherlands · Spain · Italy · Poland
-- ============================================================================
--
-- Sales bronze is NOT synthesised here. It is read live, through Lakehouse
-- Federation, out of the Postgres that owns it:
--
--     sales_rds_fed  ->  databricks_connection rds_postgres_conn  ->  RDS
--
-- Only `orders` is ingested. `crm.customers` is classified `pii` and stays in
-- Postgres — the medallion never copies email/phone/name into managed storage.
-- Seeding the source itself is the application's job, not the platform's:
-- see pipelines/sources/rds/seed.sql and ADR-0014.
--
-- Supply is still synthesised below because its source system (Azure SQL) is not
-- deployed yet; once it is, this becomes a read from `supply_sql_master`.

-- ------------------------------------------------ sales bronze (AWS, federated)
-- Be precise about what moves and what does not.
--
--   * This CTAS *does* copy: 6 040 order rows are read out of Postgres and
--     written as a Delta table under the catalog's storage_root in S3
--     (databricks-project/sales/managed-zone/). Bronze is a real, materialised
--     copy — that is what an ingest layer is.
--   * What never moves is the PII. `crm.customers` is not read here at all, and
--     where silver joins it, only `segment` and the signup year are projected.
--   * An ad-hoc query against `sales_rds_fed` (e.g. dashboard tile 13) moves
--     nothing at all: the filter and aggregate push down and only the result
--     rows come back.
--
-- Bronze is a faithful copy: no filtering, no de-duplication. The source is
-- dirty on purpose (NULL markets, refunds, replays, orphan customers) and
-- cleaning it is silver's job, where the rejects can be counted.
CREATE OR REPLACE TABLE sales_aws.bronze.sales_raw AS
SELECT
  o.order_id,
  o.customer_id,                      -- pseudonymous key; the identity behind it stays in crm
  o.market,
  o.product_sku,
  CAST(o.amount AS DOUBLE) AS amount,
  o.order_date
FROM sales_rds_fed.orders.orders AS o;

-- ---------------------------------------------------------------- supply (Azure)
-- Each market has its own supply posture, so `stockout_risk` in 03 is a finding
-- rather than noise. Lead time and stock cover are market properties here; the
-- jitter only stops the numbers looking synthetic.
--
--   Netherlands / Germany / France : short lead, deep stock  -> LOW
--   Spain / Italy                  : long lead              -> MEDIUM
--   Poland                         : longest lead AND thin stock -> HIGH
--
-- Volume follows the sales weighting (30/22/15/13/12/8), so a market's supply
-- sample size matches its commercial size.
CREATE OR REPLACE TABLE supplies_azure.bronze.supply_raw AS
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
  FROM range(4000) AS t(id)
)
SELECT
  concat('shp_', lpad(cast(id AS STRING), 6, '0'))                            AS shipment_id,
  market,
  concat('sup_', cast(rand()*40 AS INT))                                      AS supplier_id,
  element_at(array('SKU-A','SKU-B','SKU-C','SKU-D'), cast(rand()*4 AS INT)+1)  AS product_sku,
  cast(rand()*480 + 20 AS INT)                                                AS units,
  -- Base lead time per market + 0..6 days of jitter.
  cast(CASE market
         WHEN 'Netherlands' THEN 6
         WHEN 'Germany'     THEN 8
         WHEN 'France'      THEN 9
         WHEN 'Spain'       THEN 14
         WHEN 'Italy'       THEN 17
         ELSE                    23   -- Poland
       END + rand()*6 AS INT)                                                 AS lead_days,
  -- Poland runs thin: on_hand is drawn from 0..280, below a reorder band of
  -- 120..300, so ~60% of its shipments sit under the reorder point and the
  -- HIGH threshold (lead > 20 AND below_reorder > 40%) is met, not approached.
  -- Everywhere else on_hand starts at 400, above the whole band -> 0% below.
  cast(CASE WHEN market = 'Poland' THEN rand()*280 ELSE rand()*2000 + 400 END AS INT) AS on_hand,
  cast(rand()*180 + 120 AS INT)                                              AS reorder_point,
  date_add(current_date(), -cast(rand()*90 AS INT))                           AS ship_date
FROM base;
