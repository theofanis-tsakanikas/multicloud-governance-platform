-- ============================================================================
-- AWS · 02 MEDALLION  ·  bronze → silver → gold for sales + supply
--
-- Governance proof — and a stronger one than "drop the column at gold":
-- PII never enters the lakehouse at all. `crm.customers` is classified `pii` and
-- lives in Postgres. Silver joins it ONLY for non-identifying attributes
-- (segment, signup cohort); email / phone / full_name are never selected.
--
-- To reach a customer's identity you must query `sales_rds_fed.crm` directly,
-- where a different grant applies (crm_managers). The governance boundary is
-- load-bearing, not decorative.
--
-- Gold is keyed by `market` so 03 can fuse the three clouds.
-- ============================================================================

-- ---- sales silver: clean orders, enriched with the pseudonymous customer dim ----
-- Four transformations, each rejecting or repairing real defects in the source:
--   1. DISTINCT            -> collapses the 40 replayed orders
--   2. market IS NOT NULL  -> drops ~120 orders whose market never resolved
--   3. amount > 0          -> drops ~61 refunds/cancellations (not revenue)
--   4. COALESCE(segment)   -> keeps ~28 orphan orders (customer erased) as 'unknown'
--                             rather than silently dropping revenue on a join miss
CREATE OR REPLACE TABLE sales_aws.silver.sales_clean AS
SELECT DISTINCT
  o.order_id,
  o.market,
  o.customer_id,
  COALESCE(c.segment, 'unknown')      AS segment,      -- enterprise | mid_market | smb | unknown
  YEAR(c.signup_date)                 AS signup_year,  -- cohort, not an identifier
  o.product_sku,
  CAST(o.amount AS DOUBLE)            AS amount,
  o.order_date
FROM sales_aws.bronze.sales_raw AS o
LEFT JOIN sales_rds_fed.crm.customers AS c      -- federated join; PII columns NOT selected
       ON c.customer_id = o.customer_id
WHERE o.market IS NOT NULL AND o.amount > 0;

-- ---- data quality: what silver rejected, and why (auditable, not hidden) ----
CREATE OR REPLACE TABLE sales_aws.silver.sales_rejects AS
SELECT 'null_market'      AS reason, COUNT(*) AS rows FROM sales_aws.bronze.sales_raw WHERE market IS NULL
UNION ALL
SELECT 'non_positive_amount', COUNT(*) FROM sales_aws.bronze.sales_raw WHERE amount <= 0
UNION ALL
SELECT 'duplicate_replay', (SELECT COUNT(*) FROM sales_aws.bronze.sales_raw)
                         - (SELECT COUNT(*) FROM (SELECT DISTINCT * FROM sales_aws.bronze.sales_raw))
UNION ALL
SELECT 'orphan_customer', COUNT(*) FROM sales_aws.silver.sales_clean WHERE segment = 'unknown';

-- ---- gold 1 · revenue by market — "where is the money?" ----
CREATE OR REPLACE TABLE sales_aws.gold.sales_by_market AS
SELECT market,
       COUNT(*)                    AS orders,
       COUNT(DISTINCT customer_id) AS customers,
       ROUND(SUM(amount), 2)       AS revenue
FROM sales_aws.silver.sales_clean
GROUP BY market;

-- ---- gold 2 · customer value by segment — "whom do we retain?" ----
-- Pseudonymous by construction: aggregates over customer_id, never over identity.
CREATE OR REPLACE TABLE sales_aws.gold.customer_value AS
WITH per_customer AS (
  SELECT customer_id, segment, market,
         COUNT(*)        AS orders,
         SUM(amount)     AS lifetime_value,
         MAX(order_date) AS last_order_date
  FROM sales_aws.silver.sales_clean
  GROUP BY customer_id, segment, market
)
SELECT
  segment,
  market,
  COUNT(*)                      AS customers,
  ROUND(AVG(lifetime_value), 2) AS avg_lifetime_value,
  ROUND(SUM(lifetime_value), 2) AS segment_revenue,
  ROUND(AVG(orders), 1)         AS avg_orders,
  -- No order in the last 30 days: the churn-risk cohort.
  SUM(CASE WHEN last_order_date < date_add(current_date(), -30) THEN 1 ELSE 0 END) AS at_risk_customers
FROM per_customer
GROUP BY segment, market;

-- ---- gold 3 · product performance — "what do we push, what do we cut?" ----
CREATE OR REPLACE TABLE sales_aws.gold.product_performance AS
SELECT
  product_sku,
  market,
  COUNT(*)              AS orders,
  ROUND(SUM(amount), 2) AS revenue,
  ROUND(AVG(amount), 2) AS avg_order_value,
  ROUND(100.0 * SUM(amount) / SUM(SUM(amount)) OVER (PARTITION BY market), 1) AS pct_of_market_revenue
FROM sales_aws.silver.sales_clean
GROUP BY product_sku, market;

-- ---- supply silver ----
CREATE OR REPLACE TABLE supplies_azure.silver.supply_clean AS
SELECT DISTINCT
  shipment_id, market, supplier_id, product_sku,
  CAST(units AS INT) AS units, CAST(lead_days AS INT) AS lead_days,
  CAST(on_hand AS INT) AS on_hand, CAST(reorder_point AS INT) AS reorder_point, ship_date
FROM supplies_azure.bronze.supply_raw
WHERE market IS NOT NULL;

-- ---- gold 4 · supply posture by market — "where will we stock out?" ----
CREATE OR REPLACE TABLE supplies_azure.gold.supply_by_market AS
SELECT market,
       COUNT(*)                                                                          AS shipments,
       ROUND(AVG(lead_days), 1)                                                          AS avg_lead_days,
       SUM(on_hand)                                                                      AS inventory_units,
       ROUND(100.0 * SUM(CASE WHEN on_hand < reorder_point THEN 1 ELSE 0 END)/COUNT(*), 1) AS below_reorder_pct
FROM supplies_azure.silver.supply_clean
GROUP BY market;

-- ---- gold 5 · supplier lead time — "whom do we renegotiate?" ----
CREATE OR REPLACE TABLE supplies_azure.gold.supplier_leadtime AS
SELECT
  supplier_id,
  COUNT(*)                                                                      AS shipments,
  ROUND(AVG(lead_days), 1)                                                      AS avg_lead_days,
  MAX(lead_days)                                                                AS worst_lead_days,
  -- "On time" = delivered within the 14-day contractual window.
  ROUND(100.0 * SUM(CASE WHEN lead_days <= 14 THEN 1 ELSE 0 END) / COUNT(*), 1) AS on_time_pct
FROM supplies_azure.silver.supply_clean
GROUP BY supplier_id;

-- Proof: DESCRIBE sales_aws.silver.sales_clean;  -- no email / phone / full_name
