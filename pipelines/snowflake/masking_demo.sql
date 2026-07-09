-- ============================================================================
-- SNOWFLAKE · LIVE MASKING DEMO  ·  "one contract, two engines" — proven live
-- ----------------------------------------------------------------------------
-- 30-second governance demo for the recording. The SAME domain contract that
-- governs Unity Catalog is enforced on Snowflake (via infra/snowflake). Here we
-- prove the payoff a CEO understands instantly:
--
--     the ANALYST sees masked PII · the ADMIN sees the real value
--     — same query, same table, different role.
--
-- Roles below (analysts / crm_managers / metastore_admins) are the functional
-- roles the Snowflake backend creates, mirroring the UC groups. Run in a
-- Snowflake worksheet as a user who can assume them.
-- ============================================================================

USE ROLE metastore_admins;
USE WAREHOUSE governance_wh;          -- the per-domain warehouse (resource-monitor capped)

-- ── Setup: a governed table with a real PII column ─────────────────────────
CREATE DATABASE IF NOT EXISTS sales;
CREATE SCHEMA   IF NOT EXISTS sales.crm;

CREATE OR REPLACE TABLE sales.crm.customers AS
SELECT
  'cust_' || seq4()                                   AS customer_id,
  'customer' || uniform(1, 99999, random()) || '@example.com' AS email,   -- PII
  ARRAY_CONSTRUCT('EU-North','EU-South','EU-East','EU-West')[uniform(0,3,random())] AS region
FROM TABLE(generator(rowcount => 200));

-- ── The masking policy (classification-driven) ─────────────────────────────
-- Real value ONLY for admins / the CRM allowlist; masked for everyone else.
CREATE OR REPLACE MASKING POLICY sales.crm.pii_email_mask
  AS (val STRING) RETURNS STRING ->
  CASE
    WHEN CURRENT_ROLE() IN ('METASTORE_ADMINS','CRM_MANAGERS') THEN val
    ELSE '***MASKED***'
  END;

ALTER TABLE sales.crm.customers
  MODIFY COLUMN email SET MASKING POLICY sales.crm.pii_email_mask;

-- Give the analyst read access (least-privilege: SELECT only, no unmask).
GRANT USAGE  ON DATABASE sales            TO ROLE analysts;
GRANT USAGE  ON SCHEMA   sales.crm        TO ROLE analysts;
GRANT SELECT ON TABLE    sales.crm.customers TO ROLE analysts;

-- ── THE DEMO (run these two, show the difference) ──────────────────────────

-- 1) As ADMIN — sees the real email:
USE ROLE metastore_admins;
SELECT customer_id, region, email FROM sales.crm.customers LIMIT 5;
--   email → customer12345@example.com   ✅ full value

-- 2) As ANALYST — same query, PII masked:
USE ROLE analysts;
SELECT customer_id, region, email FROM sales.crm.customers LIMIT 5;
--   email → ***MASKED***                🔒 protected

-- 🗣️ Narrate: "Same contract as Databricks, enforced on Snowflake. The analyst
--            can analyse by region but can NEVER see the customer's email.
--            The governance is in the data layer — not a promise in a PDF."
