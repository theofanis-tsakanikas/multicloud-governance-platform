-- ============================================================================
-- AWS · 04 DASHBOARD QUERIES  ·  tiles for the Databricks AI/BI Dashboard
-- SQL Editor → paste query → Run → add to an AI/BI Dashboard. Zero PII exposed.
-- ============================================================================

-- TILE 1 · Revenue by region                          [BAR: x=region, y=revenue]
SELECT region, revenue FROM sales_aws.gold.executive_cross_cloud ORDER BY revenue DESC;

-- TILE 2 · Marketing ROI (demand → revenue)           [BAR: colour by marketing_roi]
SELECT region, marketing_spend, revenue, marketing_roi
FROM sales_aws.gold.executive_cross_cloud ORDER BY marketing_roi DESC;

-- TILE 3 · Supply risk                                [TABLE w/ conditional colour]
SELECT region, avg_lead_days, below_reorder_pct, stockout_risk
FROM sales_aws.gold.executive_cross_cloud ORDER BY below_reorder_pct DESC;

-- TILE 4 · Regions at stockout risk                   [COUNTER / big number]
SELECT count(*) AS regions_at_stockout_risk
FROM sales_aws.gold.executive_cross_cloud WHERE stockout_risk IN ('HIGH','MEDIUM');

-- TILE 5 · Demand vs delivery                         [SCATTER]
SELECT region, sessions AS demand, inventory_units AS supply_capacity, revenue
FROM sales_aws.gold.executive_cross_cloud;

-- TILE 6 · GOVERNANCE PROOF — gold carries zero PII    [TABLE, expect 0 rows]
SELECT column_name FROM information_schema.columns
WHERE table_catalog='sales_aws' AND table_schema='gold' AND table_name='sales_by_region'
  AND lower(column_name) RLIKE 'email|phone|ip|ssn|name';

-- TILE 7 · Headline — the whole story                 [TABLE]
SELECT region, marketing_spend, sessions, revenue, orders, marketing_roi,
       avg_lead_days, inventory_units, stockout_risk
FROM sales_aws.gold.executive_cross_cloud ORDER BY revenue DESC;
