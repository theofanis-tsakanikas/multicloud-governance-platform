-- ============================================================================
-- AWS · 03 EXECUTIVE CROSS-CLOUD VIEW  ·  the "wow"
-- Fuses all three clouds by `market`:
--   GCP marketing (Delta-shared) + AWS sales + Azure supply.
--
-- DELTA SHARING: marketing gold lives in the GCP metastore and is shared to AWS
-- by the dbx_delta_sharing layer, where it appears as `marketing_share`.
--   · real cross-cloud run → marketing_share.marketing_gcp.gold_marketing_by_market
--   · single-workspace dry run → marketing_gcp.intelligence.gold_marketing_by_market
-- ============================================================================
CREATE OR REPLACE TABLE sales_aws.gold.executive_cross_cloud AS
WITH mktg AS (
  SELECT market, campaigns, sessions, marketing_spend
  FROM   marketing_share.marketing_gcp.gold_marketing_by_market   -- DELTA-SHARED from GCP
),
sales AS (
  SELECT market, orders, customers, revenue FROM sales_aws.gold.sales_by_market
),
supply AS (
  SELECT market, avg_lead_days, inventory_units, below_reorder_pct
  FROM   supplies_azure.gold.supply_by_market
)
SELECT
  s.market,
  m.marketing_spend, m.sessions,                                   -- demand (GCP)
  s.revenue, s.orders, s.customers,                                -- revenue (AWS)
  ROUND(s.revenue / NULLIF(m.marketing_spend, 0), 2) AS marketing_roi,
  sup.avg_lead_days, sup.inventory_units, sup.below_reorder_pct,   -- delivery (Azure)
  CASE
    WHEN sup.avg_lead_days > 20 AND sup.below_reorder_pct > 40 THEN 'HIGH'
    WHEN sup.avg_lead_days > 15 OR  sup.below_reorder_pct > 25 THEN 'MEDIUM'
    ELSE 'LOW'
  END AS stockout_risk,
  -- The number an executive acts on: revenue sitting behind a fragile supply chain.
  ROUND(s.revenue * CASE
    WHEN sup.avg_lead_days > 20 AND sup.below_reorder_pct > 40 THEN 1.00
    WHEN sup.avg_lead_days > 15 OR  sup.below_reorder_pct > 25 THEN 0.40
    ELSE 0.00
  END, 2) AS revenue_at_risk
FROM sales s
JOIN mktg   m   ON m.market   = s.market
JOIN supply sup ON sup.market = s.market
ORDER BY s.revenue DESC;

-- ============================================================================
-- The same bytes, for a second engine.
--
-- `executive_cross_cloud` is a Delta table inside the catalog's managed storage,
-- which only Databricks can read. This writes the same rows once more as Parquet,
-- into the `loc_sales_gold` external location — the *same* S3 prefix the Snowflake
-- storage integration already has access to (infra/aws/.../storage_integration.tf).
--
-- Snowflake then reads those files in place. Nothing is copied into Snowflake, no
-- pipeline moves data between the engines, and both enforce the grants generated
-- from the one `sales_grants.json`. See pipelines/snowflake/read_gold_zone.sql.
--
-- The path is inside loc_sales_gold, so Unity Catalog governs the write with the
-- same external-location grants it governs everything else with.
-- ============================================================================
CREATE OR REPLACE TABLE sales_aws.gold.executive_export
USING PARQUET
LOCATION 's3://dbx-de-project-bucket-2026/databricks-project/sales/gold-zone/executive/'
AS SELECT * FROM sales_aws.gold.executive_cross_cloud;
