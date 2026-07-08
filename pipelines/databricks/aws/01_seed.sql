-- ============================================================================
-- AWS · 01 SEED  ·  region-aligned raw data for sales + supply (with PII)
-- Runs on the AWS workspace (sales_aws + supplies_azure governance live here).
-- Shared region dimension: EU-North · EU-South · EU-East · EU-West
-- ============================================================================

-- ------------------------------------------------------------------ sales (AWS)
CREATE OR REPLACE TABLE sales_aws.bronze.sales_raw AS
SELECT
  concat('ord_', lpad(cast(id AS STRING), 6, '0'))                                      AS order_id,
  element_at(array('EU-North','EU-South','EU-East','EU-West'), cast(rand()*4 AS INT)+1) AS region,
  concat('cust_', lpad(cast(rand()*800 AS INT) AS STRING, 5, '0'))                      AS customer_id,
  concat('customer', cast(rand()*99999 AS INT), '@example.com')                         AS customer_email,  -- PII
  element_at(array('SKU-A','SKU-B','SKU-C','SKU-D'), cast(rand()*4 AS INT)+1)            AS product_sku,
  round(rand()*1980 + 20, 2)                                                            AS amount,
  date_add(current_date(), -cast(rand()*90 AS INT))                                     AS order_date
FROM range(6000) AS t(id);

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
