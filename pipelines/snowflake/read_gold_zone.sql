-- ============================================================================
-- SNOWFLAKE · ZERO-COPY READ OF THE DATABRICKS GOLD LAYER
-- ----------------------------------------------------------------------------
-- The claim this file proves, live, in about 20 seconds:
--
--     Databricks wrote these bytes. Snowflake reads them where they lie.
--     Nothing was copied. Both engines enforce the same sales_grants.json.
--
-- Everything it needs already exists, created by `terragrunt apply` on the AWS
-- stack — no setup step here touches infrastructure:
--
--   · DEV_STORAGE_INTEGRATION      the S3 <-> Snowflake IAM trust
--   · "sales_aws"."_EXTERNAL"."loc_sales_gold"
--                                  an external stage over
--                                  s3://dbx-de-project-bucket-2026/databricks-project/sales/gold-zone/
--   · DEV_ANALYSTS, DEV_METASTORE_ADMINS, ...
--                                  the functional roles translated from the domain
--
-- ⚠ TWO THINGS THAT MATTER, both verified against the live account:
--
--   1. Identifiers are QUOTED. Terraform created the database and stages with
--      lowercase names ("sales_aws", "loc_sales_gold"). Snowflake upper-cases an
--      unquoted identifier, so `sales_aws` resolves to SALES_AWS and does not
--      exist. Every lowercase name below is quoted.
--
--   2. Your user must be able to assume the functional roles. One-time setup, run
--      once as ACCOUNTADMIN (replace THEOFANIS with your user):
--          GRANT ROLE DEV_METASTORE_ADMINS TO USER THEOFANIS;
--          GRANT ROLE DEV_ANALYSTS         TO USER THEOFANIS;
--
-- The Parquet files under `executive/` are written by the last statement of
-- pipelines/databricks/aws/03_executive.sql. Run the medallion first.
-- ============================================================================

-- Setup runs as ACCOUNTADMIN: it creates the demo scaffolding and the external
-- table, and grants the functional role read access. The DEMO itself then runs as
-- DEV_ANALYSTS. (A functional role has no CREATE on this ad-hoc schema, and does
-- not need it — creating scaffolding is an admin action, reading it is the point.)
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE DEV_SALES_WH;          -- resource-monitor capped (100 credits/month)
USE DATABASE "sales_aws";

-- ── A schema for objects that are NOT part of the governed domain ───────────
CREATE SCHEMA IF NOT EXISTS "sales_aws"."demo"
  COMMENT = 'Not governed by the domain contract. Demo scaffolding only.';

CREATE OR REPLACE FILE FORMAT "sales_aws"."demo"."parquet_ff" TYPE = PARQUET;

-- ── The external table: a pointer, not a copy ───────────────────────────────
-- Columns are declared explicitly against the Parquet fields. (INFER_SCHEMA via
-- USING TEMPLATE is the alternative, but it is brittle with quoted names — the
-- explicit form is both robust and self-documenting.)
CREATE OR REPLACE EXTERNAL TABLE "sales_aws"."demo"."executive_cross_cloud" (
    market          STRING AS (VALUE:market::STRING),
    revenue         DOUBLE AS (VALUE:revenue::DOUBLE),
    marketing_roi   DOUBLE AS (VALUE:marketing_roi::DOUBLE),
    stockout_risk   STRING AS (VALUE:stockout_risk::STRING),
    revenue_at_risk DOUBLE AS (VALUE:revenue_at_risk::DOUBLE)
  )
  LOCATION    = @"sales_aws"."_EXTERNAL"."loc_sales_gold"/executive/
  FILE_FORMAT = "sales_aws"."demo"."parquet_ff"
  AUTO_REFRESH = FALSE
  PATTERN = '.*[.]parquet';

-- Least privilege, from the same vocabulary the domain uses: analysts read.
GRANT USAGE  ON SCHEMA "sales_aws"."demo"                              TO ROLE DEV_ANALYSTS;
GRANT SELECT ON EXTERNAL TABLE "sales_aws"."demo"."executive_cross_cloud" TO ROLE DEV_ANALYSTS;

-- ─────────────────────────────── THE DEMO ──────────────────────────────────

-- 1) Snowflake reads the cross-cloud executive table Databricks built.
--    Three clouds fused by `market`, queried by a fourth engine.
USE ROLE DEV_ANALYSTS;

SELECT market, revenue, marketing_roi, stockout_risk, revenue_at_risk
FROM   "sales_aws"."demo"."executive_cross_cloud"
ORDER  BY revenue DESC;

-- 2) Where does it actually live? Not in Snowflake.
SELECT DISTINCT metadata$filename AS s3_object
FROM   "sales_aws"."demo"."executive_cross_cloud";
--   -> databricks-project/sales/gold-zone/executive/part-00000-....snappy.parquet

-- 🗣️ Narrate: "The gold layer was written once, by Databricks, into S3. Snowflake
--            queries it in place — no ingestion, no second copy, no divergence.
--            Both engines enforce grants generated from one JSON contract, and
--            `snowflake_backend.py --check` proves the two are access-equivalent."
