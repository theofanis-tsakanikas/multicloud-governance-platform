-- ============================================================================
-- AWS · 01 SEED  ·  ingest from the federated source; no PII enters the lakehouse
-- Runs on the AWS workspace (sales_aws + supplies_azure governance live here).
-- Shared market dimension (the cross-cloud join key, NOT a cloud region):
--   Germany · France · Netherlands · Spain · Italy · Poland
-- ============================================================================
-- The serverless warehouse's default catalog is `hive_metastore`, and legacy
-- access is turned off on this account. Any DDL issued from such a session fails
-- with UC_HIVE_METASTORE_DISABLED_EXCEPTION — even when every name in the
-- statement is fully qualified, because the check is on the session, not on the
-- identifiers. A job's SQL task runs the whole file in one session, so one
-- statement fixes the file. Three-part names below still address other catalogs.
USE CATALOG sales_aws;

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
-- The same holds for supply below: it is read from `supply_sql_master`, the
-- FOREIGN catalog over Azure SQL, seeded by pipelines/sources/azure_sql/seed.sql.

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

-- ------------------------------------------- supply bronze (Azure, federated)
-- The supply chain lives in Azure SQL. `supply_sql_master` federates it, and this
-- joins ACROSS its two schemas — orders and inventory — in one query, from a
-- Databricks workspace on AWS. Neither schema is copied into Azure storage; the
-- join predicate pushes down and only the result rows cross the wire.
--
-- inventory.stock carries no PII and orders.purchase_orders carries none either;
-- supply chain data is `confidential`, not `pii`. There is nothing to leave behind.
CREATE OR REPLACE TABLE supplies_azure.bronze.supply_raw AS
SELECT
  po.po_id        AS shipment_id,
  po.market,
  po.supplier_id,
  po.sku          AS product_sku,
  CAST(po.units     AS INT) AS units,
  CAST(po.lead_days AS INT) AS lead_days,
  CAST(st.on_hand       AS INT) AS on_hand,
  CAST(st.reorder_point AS INT) AS reorder_point,
  po.ship_date
FROM      supply_sql_master.orders.purchase_orders AS po
LEFT JOIN supply_sql_master.inventory.stock        AS st
       ON st.sku = po.sku AND st.market = po.market;
