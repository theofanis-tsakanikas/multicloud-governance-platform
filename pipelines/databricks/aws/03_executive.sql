-- ============================================================================
-- AWS · 03 EXECUTIVE CROSS-CLOUD VIEW  ·  the "wow"
-- Fuses all three clouds by `region`:
--   GCP marketing (Delta-shared) + AWS sales + Azure supply.
--
-- DELTA SHARING: marketing gold lives in the GCP metastore and is shared to AWS
-- by the dbx_delta_sharing layer, where it appears as `marketing_share`.
--   · real cross-cloud run → marketing_share.marketing_gcp.gold_marketing_by_region
--   · single-workspace dry run → marketing_gcp.intelligence.gold_marketing_by_region
-- ============================================================================
CREATE OR REPLACE TABLE sales_aws.gold.executive_cross_cloud AS
WITH mktg AS (
  SELECT region, campaigns, sessions, marketing_spend
  FROM   marketing_share.marketing_gcp.gold_marketing_by_region   -- DELTA-SHARED from GCP
),
sales AS (
  SELECT region, orders, customers, revenue FROM sales_aws.gold.sales_by_region
),
supply AS (
  SELECT region, avg_lead_days, inventory_units, below_reorder_pct
  FROM   supplies_azure.silver.supply_by_region
)
SELECT
  s.region,
  m.marketing_spend, m.sessions,                                   -- demand (GCP)
  s.revenue, s.orders, s.customers,                                -- revenue (AWS)
  ROUND(s.revenue / NULLIF(m.marketing_spend, 0), 2) AS marketing_roi,
  sup.avg_lead_days, sup.inventory_units, sup.below_reorder_pct,   -- delivery (Azure)
  CASE
    WHEN sup.avg_lead_days > 20 AND sup.below_reorder_pct > 40 THEN 'HIGH'
    WHEN sup.avg_lead_days > 15 OR  sup.below_reorder_pct > 25 THEN 'MEDIUM'
    ELSE 'LOW'
  END AS stockout_risk
FROM sales s
JOIN mktg   m   ON m.region   = s.region
JOIN supply sup ON sup.region = s.region
ORDER BY s.revenue DESC;
