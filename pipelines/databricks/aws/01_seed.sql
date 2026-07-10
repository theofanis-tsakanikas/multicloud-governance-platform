-- ============================================================================
-- AWS · 01 SEED  ·  ingest from the federated source; no PII enters the lakehouse
-- Runs on the AWS workspace (sales_aws + supplies_azure governance live here).
-- Shared region dimension: EU-North · EU-South · EU-East · EU-West
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
-- dirty on purpose (NULL regions, refunds, replays, orphan customers) and
-- cleaning it is silver's job, where the rejects can be counted.
CREATE OR REPLACE TABLE sales_aws.bronze.sales_raw AS
SELECT
  o.order_id,
  o.customer_id,                      -- pseudonymous key; the identity behind it stays in crm
  o.region,
  o.product_sku,
  CAST(o.amount AS DOUBLE) AS amount,
  o.order_date
FROM sales_rds_fed.orders.orders AS o;

-- ---------------------------------------------------------------- supply (Azure)
CREATE OR REPLACE TABLE supplies_azure.bronze.supply_raw AS
SELECT
  concat('shp_', lpad(cast(id AS STRING), 6, '0'))                                      AS shipment_id,
  element_at(array('EU-North','EU-South','EU-East','EU-West'), cast(rand()*4 AS INT)+1) AS region,
  concat('sup_', cast(rand()*40 AS INT))                                                AS supplier_id,
  element_at(array('SKU-A','SKU-B','SKU-C','SKU-D'), cast(rand()*4 AS INT)+1)            AS product_sku,
  cast(rand()*480 + 20 AS INT)                                                          AS units,
  cast(rand()*28 + 2 AS INT)                                                            AS lead_days,
  cast(rand()*2000 AS INT)                                                              AS on_hand,
  cast(rand()*250 + 50 AS INT)                                                          AS reorder_point,
  date_add(current_date(), -cast(rand()*90 AS INT))                                     AS ship_date
FROM range(4000) AS t(id);
