-- Medallion transformations as Spark SQL — the LIVE-platform equivalent of
-- pipelines/medallion.py (which runs the same shape offline in sqlite).
--
-- DEFERRED, like genie_space.py --deploy and catalog_drift.py --live: running
-- this needs a Databricks workspace + the governed Unity Catalog. It is the
-- production face of Level B — the offline sqlite warehouse is the reproducible
-- demo of exactly this logic.
--
-- The catalogs/schemas referenced here are the ones provisioned by the platform
-- (see environments/dev/domains/). PII (full_name/email/phone, user_email/
-- ip_address) is carried through silver and DROPPED at gold — the same
-- PII-minimisation the offline profiler asserts.

-- ============================================================================
-- AWS · sales · gold
-- ============================================================================

-- Revenue by region (pure aggregate — no PII).
CREATE OR REPLACE TABLE sales_aws.gold.revenue_by_region AS
SELECT region,
       COUNT(*)                 AS sales,
       ROUND(SUM(revenue), 2)   AS revenue
FROM   sales_aws.silver.sales
GROUP  BY region;

-- Customer value: joins federated CRM (PII) with orders, but PROJECTS AWAY
-- email/phone/full_name — gold keeps only the pseudonymous id + country.
CREATE OR REPLACE TABLE sales_aws.gold.customer_value AS
SELECT c.customer_id,
       c.country,
       COUNT(o.order_id)        AS orders,
       ROUND(SUM(o.amount), 2)  AS total_amount
FROM   sales_rds_fed.crm    AS c
LEFT   JOIN sales_rds_fed.orders AS o ON o.customer_id = c.customer_id
GROUP  BY c.customer_id, c.country;

-- ============================================================================
-- GCP · marketing · gold  (web PII aggregated away to bare counts)
-- ============================================================================

CREATE OR REPLACE TABLE marketing_gcp.intelligence.web_by_country AS
SELECT country,
       COUNT(DISTINCT session_id) AS sessions
FROM   marketing_bq_fed.web          -- user_email + ip_address NEVER leave silver
GROUP  BY country;

-- ============================================================================
-- Cross-cloud KPIs — the Delta Sharing story, executed
-- ----------------------------------------------------------------------------
-- marketing_gcp is shared to the AWS metastore (see ADR-0009); this single
-- table spans all three clouds under one Unity Catalog governance plane.
-- ============================================================================

CREATE OR REPLACE TABLE sales_aws.gold.global_kpis AS
SELECT 'AWS'   AS cloud, 'sales'        AS domain, 'revenue'        AS kpi, ROUND(SUM(revenue), 2)  AS value FROM sales_aws.gold.revenue_by_region
UNION ALL
SELECT 'AZURE' AS cloud, 'supply_chain' AS domain, 'units_shipped'  AS kpi, SUM(units)              AS value FROM supplies_azure.silver.shipments
UNION ALL
SELECT 'GCP'   AS cloud, 'marketing'    AS domain, 'campaign_spend' AS kpi, ROUND(SUM(spend), 2)    AS value FROM marketing_bq_fed.analytics;
