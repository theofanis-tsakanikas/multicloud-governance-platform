-- ============================================================================
-- AWS · 02 MEDALLION  ·  bronze → silver → gold for sales + supply
-- Governance proof: PII (customer_email) stays in SILVER, dropped in GOLD.
-- Gold is keyed by `region` so 03 can fuse the three clouds.
-- ============================================================================

-- ---- sales silver (KEEPS customer_email — governed) ----
CREATE OR REPLACE TABLE sales_aws.silver.sales_clean AS
SELECT DISTINCT
  order_id, region, customer_id,
  customer_email,                       -- PII
  product_sku, CAST(amount AS DOUBLE) AS amount, order_date
FROM sales_aws.bronze.sales_raw
WHERE region IS NOT NULL AND amount > 0;

-- ---- sales gold (NO PII) ----
CREATE OR REPLACE TABLE sales_aws.gold.sales_by_region AS
SELECT region,
       COUNT(*)                    AS orders,
       COUNT(DISTINCT customer_id) AS customers,
       ROUND(SUM(amount), 2)       AS revenue
FROM sales_aws.silver.sales_clean
GROUP BY region;

-- ---- supply silver ----
CREATE OR REPLACE TABLE supplies_azure.silver.supply_clean AS
SELECT DISTINCT
  shipment_id, region, supplier_id, product_sku,
  CAST(units AS INT) AS units, CAST(lead_days AS INT) AS lead_days,
  CAST(on_hand AS INT) AS on_hand, CAST(reorder_point AS INT) AS reorder_point, ship_date
FROM supplies_azure.bronze.supply_raw
WHERE region IS NOT NULL;

-- ---- supply gold (by region) ----
CREATE OR REPLACE TABLE supplies_azure.silver.supply_by_region AS
SELECT region,
       COUNT(*)                                                                          AS shipments,
       ROUND(AVG(lead_days), 1)                                                          AS avg_lead_days,
       SUM(on_hand)                                                                      AS inventory_units,
       ROUND(100.0 * SUM(CASE WHEN on_hand < reorder_point THEN 1 ELSE 0 END)/COUNT(*), 1) AS below_reorder_pct
FROM supplies_azure.silver.supply_clean
GROUP BY region;

-- Proof: DESCRIBE sales_aws.gold.sales_by_region;  -- no customer_email
