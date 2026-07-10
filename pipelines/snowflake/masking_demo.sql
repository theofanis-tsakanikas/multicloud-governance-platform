-- ============================================================================
-- SNOWFLAKE · LIVE MASKING DEMO  ·  the policy mechanism, shown on real rows
-- ----------------------------------------------------------------------------
--     the ANALYST sees masked PII · the ADMIN sees the real value
--     — same query, same table, different role.
--
-- ⚠ READ THIS FIRST — this file creates PII, and that is deliberate.
--
-- The governed platform holds no PII at all. `crm.customers` lives in Postgres and
-- is reached through Lakehouse Federation; nothing copies email, phone or name
-- into managed storage (see pipelines/databricks/aws/02_medallion.sql). So there
-- is no PII column anywhere for a masking policy to mask.
--
-- Rather than pretend, this demo builds its own PII table in "sales_aws"."demo" —
-- a schema NOT declared in domains/aws/sales_infra.json, not governed by the
-- domain contract, existing only to exercise the masking mechanism the Snowflake
-- backend deploys (infra/snowflake/modules/global/masking).
--
-- ⚠ TWO THINGS THAT MATTER, both verified against the live account:
--
--   1. Identifiers are QUOTED. Terraform created the database lowercase
--      ("sales_aws"); an unquoted `sales_aws` upper-cases to SALES_AWS and does
--      not exist.
--
--   2. Your user must be able to assume the roles. One-time setup, run once as
--      ACCOUNTADMIN (replace THEOFANIS with your user):
--          GRANT ROLE DEV_METASTORE_ADMINS TO USER THEOFANIS;
--          GRANT ROLE DEV_ANALYSTS         TO USER THEOFANIS;
--
-- `crm_managers` has no Snowflake role: it appears only in grants on the FEDERATED
-- catalog, which the Snowflake backend filters out.
-- ============================================================================

-- Setup runs as ACCOUNTADMIN (it creates a schema, a table and a policy). The
-- DEMO then switches roles to show masked vs unmasked — that role switch is the
-- whole point, and it is all a functional role needs to do here.
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE DEV_SALES_WH;          -- resource-monitor capped (100 credits/month)
USE DATABASE "sales_aws";

CREATE SCHEMA IF NOT EXISTS "sales_aws"."demo"
  COMMENT = 'Not governed by the domain contract. Demo scaffolding only.';

-- ── Setup: a table with a real PII column, outside the governed schemas ─────
CREATE OR REPLACE TABLE "sales_aws"."demo"."customers" AS
SELECT
  'cust_' || seq4()                                                            AS customer_id,
  'customer' || uniform(1, 99999, random()) || '@example.com'                  AS email,   -- PII
  ARRAY_CONSTRUCT('Germany','France','Netherlands','Spain','Italy','Poland')[uniform(0,5,random())]::STRING AS market
FROM TABLE(generator(rowcount => 200));

-- ── The masking policy ─────────────────────────────────────────────────────
-- Real value only for the admin role. Everyone else — including anyone granted
-- SELECT tomorrow — sees the mask. The policy travels with the column.
CREATE OR REPLACE MASKING POLICY "sales_aws"."demo"."pii_email_mask"
  AS (val STRING) RETURNS STRING ->
  CASE
    WHEN CURRENT_ROLE() = 'DEV_METASTORE_ADMINS' THEN val
    ELSE '***MASKED***'
  END;

ALTER TABLE "sales_aws"."demo"."customers"
  MODIFY COLUMN email SET MASKING POLICY "sales_aws"."demo"."pii_email_mask";

-- Least privilege: the analyst reads the table. Nothing grants "unmask" —
-- there is no such privilege. The policy is evaluated at query time.
GRANT USAGE  ON SCHEMA "sales_aws"."demo"             TO ROLE DEV_ANALYSTS;
GRANT SELECT ON TABLE  "sales_aws"."demo"."customers" TO ROLE DEV_ANALYSTS;
-- The admin role must also hold read on this ad-hoc table to see the unmasked value.
GRANT USAGE  ON SCHEMA "sales_aws"."demo"             TO ROLE DEV_METASTORE_ADMINS;
GRANT SELECT ON TABLE  "sales_aws"."demo"."customers" TO ROLE DEV_METASTORE_ADMINS;

-- ─────────────────────────────── THE DEMO ──────────────────────────────────

-- 1) As ADMIN — sees the real email:
USE ROLE DEV_METASTORE_ADMINS;
SELECT customer_id, market, email FROM "sales_aws"."demo"."customers" LIMIT 5;
--   email -> customer12345@example.com   ✅ full value

-- 2) As ANALYST — same query, same table, PII masked:
USE ROLE DEV_ANALYSTS;
SELECT customer_id, market, email FROM "sales_aws"."demo"."customers" LIMIT 5;
--   email -> ***MASKED***                🔒 protected

-- 3) The analyst can still do their job — aggregate by market:
SELECT market, count(*) AS customers
FROM   "sales_aws"."demo"."customers"
GROUP  BY market ORDER BY customers DESC;

-- 🗣️ Narrate: "Column-level masking, enforced by the engine at query time — not by
--            a view, not by a promise in a PDF. On the governed catalogs there is
--            nothing to mask, because the PII never left Postgres. This schema
--            exists to show you the mechanism."

-- ── Cleanup (the demo schema is not governed state) ────────────────────────
-- USE ROLE DEV_METASTORE_ADMINS;
-- DROP SCHEMA "sales_aws"."demo" CASCADE;
