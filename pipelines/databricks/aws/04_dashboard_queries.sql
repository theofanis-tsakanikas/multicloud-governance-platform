-- ============================================================================
-- AWS · 04 DASHBOARD QUERIES  ·  tiles for the Databricks AI/BI Dashboard
-- SQL Editor → paste query → Run → add to an AI/BI Dashboard. Zero PII exposed.
--
-- Every tile answers a decision, not a curiosity. Tile 10 audits data quality;
-- the last three are the governance proof: gold carries no PII, silver carries
-- none either, and the PII that does exist never left the source system.
-- ============================================================================

-- TILE 1 · Revenue by region                          [BAR: x=region, y=revenue]
SELECT region, revenue FROM sales_aws.gold.executive_cross_cloud ORDER BY revenue DESC;

-- TILE 2 · Marketing ROI (demand → revenue)           [BAR: colour by marketing_roi]
-- Decision: where does the next marketing euro go?
SELECT region, marketing_spend, revenue, marketing_roi
FROM sales_aws.gold.executive_cross_cloud ORDER BY marketing_roi DESC;

-- TILE 3 · Supply risk                                [TABLE w/ conditional colour]
SELECT region, avg_lead_days, below_reorder_pct, stockout_risk
FROM sales_aws.gold.executive_cross_cloud ORDER BY below_reorder_pct DESC;

-- TILE 4 · Revenue at risk                            [COUNTER / big number]
-- Decision: how much revenue sits behind a fragile supply chain, right now?
SELECT ROUND(SUM(revenue_at_risk), 2) AS revenue_at_risk_eur
FROM sales_aws.gold.executive_cross_cloud;

-- TILE 5 · Demand vs delivery                         [SCATTER]
SELECT region, sessions AS demand, inventory_units AS supply_capacity, revenue
FROM sales_aws.gold.executive_cross_cloud;

-- TILE 6 · Customer segments worth retaining          [BAR: y=segment_revenue]
-- Decision: which segment earns a retention budget? (pseudonymous — no identities)
SELECT segment, SUM(customers) AS customers, ROUND(SUM(segment_revenue), 2) AS segment_revenue,
       SUM(at_risk_customers) AS at_risk_customers
FROM sales_aws.gold.customer_value GROUP BY segment ORDER BY segment_revenue DESC;

-- TILE 7 · Product mix by region                      [STACKED BAR]
-- Decision: which SKU to push, which to cut, and where?
SELECT region, product_sku, revenue, pct_of_region_revenue
FROM sales_aws.gold.product_performance ORDER BY region, revenue DESC;

-- TILE 8 · Suppliers to renegotiate                   [TABLE, worst 10]
-- Decision: which supplier contract is causing the stockout risk in tile 3?
SELECT supplier_id, shipments, avg_lead_days, worst_lead_days, on_time_pct
FROM supplies_azure.gold.supplier_leadtime
WHERE shipments >= 20 ORDER BY on_time_pct ASC LIMIT 10;

-- TILE 9 · Headline — the whole story                 [TABLE]
SELECT region, marketing_spend, sessions, revenue, orders, marketing_roi,
       avg_lead_days, inventory_units, stockout_risk, revenue_at_risk
FROM sales_aws.gold.executive_cross_cloud ORDER BY revenue DESC;

-- TILE 10 · Data quality — what silver rejected, and why   [BAR: x=reason, y=rows]
-- The source is a real OLTP system: it replays orders, loses regions, issues
-- refunds, and erases customers. Bronze copies it faithfully; silver rejects on
-- the record. 6 040 bronze rows -> 5 820 silver rows.
SELECT reason, rows FROM sales_aws.silver.sales_rejects ORDER BY rows DESC;

-- ─────────────────────────── GOVERNANCE PROOF ───────────────────────────────

-- TILE 11 · Gold carries zero PII                     [TABLE, expect 0 rows]
SELECT table_name, column_name FROM sales_aws.information_schema.columns
WHERE table_schema = 'gold' AND lower(column_name) RLIKE 'email|phone|ip|ssn|name';

-- TILE 12 · Neither does SILVER — the PII never entered the lakehouse
--                                                     [TABLE, expect 0 rows]
SELECT table_name, column_name FROM sales_aws.information_schema.columns
WHERE table_schema = 'silver' AND lower(column_name) RLIKE 'email|phone|ssn|full_name';

-- TILE 13 · …because it is still in the source system, governed in place
-- The identities exist and are queryable — through the FEDERATED catalog, where
-- `sales_rds_fed.crm` is classified `pii` and granted only to crm_managers.
-- Run this as an analyst and it fails: that is the boundary doing its job.
SELECT COUNT(*) AS customers_in_source, COUNT(DISTINCT segment) AS segments
FROM sales_rds_fed.crm.customers;
