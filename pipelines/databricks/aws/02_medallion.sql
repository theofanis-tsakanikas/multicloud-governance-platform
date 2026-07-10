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
-- Gold is keyed by `region` so 03 can fuse the three clouds.
-- ============================================================================

-- ---- sales silver: clean orders, enriched with the pseudonymous customer dim ----
CREATE OR REPLACE TABLE sales_aws.silver.sales_clean AS
SELECT DISTINCT
  o.order_id,
  o.region,
  o.customer_id,
  c.segment,                                    -- enterprise | mid_market | smb
  YEAR(c.signup_date) AS signup_year,           -- cohort, not an identifier
  o.product_sku,
  CAST(o.amount AS DOUBLE) AS amount,
  o.order_date
FROM sales_aws.bronze.sales_raw AS o
LEFT JOIN sales_rds_fed.crm.customers AS c      -- federated join; PII columns NOT selected
       ON c.customer_id = o.customer_id
WHERE o.region IS NOT NULL AND o.amount > 0;

-- ---- gold 1 · revenue by region — "where is the money?" ----
CREATE OR REPLACE TABLE sales_aws.gold.sales_by_region AS
SELECT region,
       COUNT(*)                    AS orders,
       COUNT(DISTINCT customer_id) AS customers,
       ROUND(SUM(amount), 2)       AS revenue
FROM sales_aws.silver.sales_clean
GROUP BY region;

-- ---- gold 2 · customer value by segment — "whom do we retain?" ----
-- Pseudonymous by construction: aggregates over customer_id, never over identity.
CREATE OR REPLACE TABLE sales_aws.gold.customer_value AS
WITH per_customer AS (
  SELECT customer_id, segment, region,
         COUNT(*)        AS orders,
         SUM(amount)     AS lifetime_value,
         MAX(order_date) AS last_order_date
  FROM sales_aws.silver.sales_clean
  GROUP BY customer_id, segment, region
)
SELECT
  segment,
  region,
  COUNT(*)                      AS customers,
  ROUND(AVG(lifetime_value), 2) AS avg_lifetime_value,
  ROUND(SUM(lifetime_value), 2) AS segment_revenue,
  ROUND(AVG(orders), 1)         AS avg_orders,
  -- No order in the last 30 days: the churn-risk cohort.
  SUM(CASE WHEN last_order_date < date_add(current_date(), -30) THEN 1 ELSE 0 END) AS at_risk_customers
FROM per_customer
GROUP BY segment, region;

-- ---- gold 3 · product performance — "what do we push, what do we cut?" ----
CREATE OR REPLACE TABLE sales_aws.gold.product_performance AS
SELECT
  product_sku,
  region,
  COUNT(*)              AS orders,
  ROUND(SUM(amount), 2) AS revenue,
  ROUND(AVG(amount), 2) AS avg_order_value,
  ROUND(100.0 * SUM(amount) / SUM(SUM(amount)) OVER (PARTITION BY region), 1) AS pct_of_region_revenue
FROM sales_aws.silver.sales_clean
GROUP BY product_sku, region;

-- ---- supply silver ----
CREATE OR REPLACE TABLE supplies_azure.silver.supply_clean AS
SELECT DISTINCT
  shipment_id, region, supplier_id, product_sku,
  CAST(units AS INT) AS units, CAST(lead_days AS INT) AS lead_days,
  CAST(on_hand AS INT) AS on_hand, CAST(reorder_point AS INT) AS reorder_point, ship_date
FROM supplies_azure.bronze.supply_raw
WHERE region IS NOT NULL;

-- ---- gold 4 · supply posture by region — "where will we stock out?" ----
CREATE OR REPLACE TABLE supplies_azure.gold.supply_by_region AS
SELECT region,
       COUNT(*)                                                                          AS shipments,
       ROUND(AVG(lead_days), 1)                                                          AS avg_lead_days,
       SUM(on_hand)                                                                      AS inventory_units,
       ROUND(100.0 * SUM(CASE WHEN on_hand < reorder_point THEN 1 ELSE 0 END)/COUNT(*), 1) AS below_reorder_pct
FROM supplies_azure.silver.supply_clean
GROUP BY region;

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
