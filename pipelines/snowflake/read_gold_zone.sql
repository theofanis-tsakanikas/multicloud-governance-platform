-- ============================================================================
-- SNOWFLAKE · ZERO-COPY READ OF THE DATABRICKS GOLD LAYER
-- ----------------------------------------------------------------------------
-- The claim this file proves, live, in about 20 seconds:
--
--     Databricks wrote these bytes. Snowflake reads them where they lie.
--     Nothing was copied. Both engines enforce the same sales_grants.json.
--
-- Everything it needs already exists, created by `terragrunt apply` on the AWS
-- stack — no setup step in this script touches infrastructure:
--
--   · DEV_STORAGE_INTEGRATION      the S3 <-> Snowflake IAM trust
--   · sales_aws._EXTERNAL.loc_sales_gold
--                                  an external stage over
--                                  s3://dbx-de-project-bucket-2026/databricks-project/sales/gold-zone/
--   · DEV_ANALYSTS, DEV_METASTORE_ADMINS, ...
--                                  the functional roles translated from the domain
--
-- The Parquet files under `executive/` are written by the last statement of
-- pipelines/databricks/aws/03_executive.sql. Run the medallion first.
-- ============================================================================

USE ROLE DEV_METASTORE_ADMINS;
USE WAREHOUSE DEV_SALES_WH;          -- resource-monitor capped (100 credits/month)
USE DATABASE sales_aws;

-- ── A schema for objects that are NOT part of the governed domain ───────────
-- `bronze`, `silver` and `gold` come from domains/aws/sales_infra.json and are
-- created by Terraform. Anything here is demo scaffolding, and is named so that
-- nobody mistakes it for governed state.
CREATE SCHEMA IF NOT EXISTS sales_aws.demo
  COMMENT = 'Not governed by the domain contract. Demo scaffolding only.';

CREATE FILE FORMAT IF NOT EXISTS sales_aws.demo.parquet_ff TYPE = PARQUET;

-- ── The external table: a pointer, not a copy ───────────────────────────────
-- INFER_SCHEMA reads the Parquet footers, so the column list follows whatever
-- 03_executive.sql produced. No DDL to keep in sync between the two engines.
CREATE OR REPLACE EXTERNAL TABLE sales_aws.demo.executive_cross_cloud
  LOCATION     = @sales_aws._EXTERNAL.loc_sales_gold/executive/
  FILE_FORMAT  = sales_aws.demo.parquet_ff
  AUTO_REFRESH = FALSE
  USING TEMPLATE (
    SELECT ARRAY_AGG(OBJECT_CONSTRUCT(*))
    FROM TABLE(INFER_SCHEMA(
      LOCATION    => '@sales_aws._EXTERNAL.loc_sales_gold/executive/',
      FILE_FORMAT => 'sales_aws.demo.parquet_ff'
    ))
  );

ALTER EXTERNAL TABLE sales_aws.demo.executive_cross_cloud REFRESH;

-- Least privilege, from the same vocabulary the domain uses: analysts read.
GRANT USAGE  ON SCHEMA sales_aws.demo                        TO ROLE DEV_ANALYSTS;
GRANT SELECT ON EXTERNAL TABLE sales_aws.demo.executive_cross_cloud TO ROLE DEV_ANALYSTS;

-- ─────────────────────────────── THE DEMO ──────────────────────────────────

-- 1) Snowflake reads the cross-cloud executive table Databricks built.
--    Three clouds fused by `market`, queried by a fourth engine.
USE ROLE DEV_ANALYSTS;

SELECT market, revenue, marketing_roi, stockout_risk, revenue_at_risk
FROM   sales_aws.demo.executive_cross_cloud
ORDER  BY revenue DESC;

-- 2) Where does it actually live? Not in Snowflake.
SELECT DISTINCT metadata$filename AS s3_object
FROM   sales_aws.demo.executive_cross_cloud;
--   → databricks-project/sales/gold-zone/executive/part-00000-....snappy.parquet

-- 3) And the same governance proof as everywhere else: no PII crossed over.
SELECT column_name
FROM   sales_aws.information_schema.columns
WHERE  table_schema = 'DEMO'
  AND  lower(column_name) RLIKE 'email|phone|ssn|name';
--   → 0 rows

-- 🗣️ Narrate: "The gold layer was written once, by Databricks, into S3. Snowflake
--            queries it in place — no ingestion, no second copy, no divergence.
--            Both engines enforce grants generated from one JSON contract, and
--            `snowflake_backend.py --check` proves the two are access-equivalent."
