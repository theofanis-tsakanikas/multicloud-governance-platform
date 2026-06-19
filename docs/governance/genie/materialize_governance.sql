-- Governance grounding tables for the Genie copilot.
-- GENERATED from docs/governance/governance_context.json — do not edit by hand.
-- Run on the serverless SQL warehouse. These tables are READ-ONLY facts;
-- Genie is instructed to answer only from them.

CREATE SCHEMA IF NOT EXISTS platform_governance.catalog;

CREATE OR REPLACE TABLE platform_governance.catalog.objects (
  cloud STRING, domain STRING, object_type STRING, name STRING,
  classification STRING, owner STRING, catalog_type STRING
);
INSERT INTO platform_governance.catalog.objects (cloud, domain, object_type, name, classification, owner, catalog_type) VALUES
  ('AWS', 'sales', 'external_location', 'loc_sales_raw', NULL, NULL, NULL),
  ('AWS', 'sales', 'external_location', 'loc_sales_managed', NULL, NULL, NULL),
  ('AWS', 'sales', 'external_location', 'loc_sales_gold', NULL, NULL, NULL),
  ('AWS', 'sales', 'catalog', 'sales_aws', NULL, 'data_engineers', 'MANAGED'),
  ('AWS', 'sales', 'schema', 'sales_aws.bronze', 'confidential', NULL, 'MANAGED'),
  ('AWS', 'sales', 'volume', 'sales_aws.bronze.sales_landing_zone', 'confidential', NULL, 'MANAGED'),
  ('AWS', 'sales', 'schema', 'sales_aws.silver', 'confidential', NULL, 'MANAGED'),
  ('AWS', 'sales', 'schema', 'sales_aws.gold', 'internal', NULL, 'MANAGED'),
  ('AWS', 'sales', 'catalog', 'sales_rds_fed', NULL, 'data_engineers', 'FEDERATED'),
  ('AWS', 'sales', 'schema', 'sales_rds_fed.crm', 'pii', NULL, 'FEDERATED'),
  ('AWS', 'sales', 'schema', 'sales_rds_fed.orders', 'confidential', NULL, 'FEDERATED'),
  ('AZURE', 'supply_chain', 'external_location', 'loc_supply_raw', NULL, NULL, NULL),
  ('AZURE', 'supply_chain', 'external_location', 'loc_supply_managed', NULL, NULL, NULL),
  ('AZURE', 'supply_chain', 'catalog', 'supplies_azure', NULL, 'data_engineers', 'MANAGED'),
  ('AZURE', 'supply_chain', 'schema', 'supplies_azure.bronze', 'confidential', NULL, 'MANAGED'),
  ('AZURE', 'supply_chain', 'volume', 'supplies_azure.bronze.supplies_landing_zone', 'confidential', NULL, 'MANAGED'),
  ('AZURE', 'supply_chain', 'schema', 'supplies_azure.silver', 'confidential', NULL, 'MANAGED'),
  ('AZURE', 'supply_chain', 'catalog', 'supply_sql_master', NULL, 'data_engineers', 'FEDERATED'),
  ('AZURE', 'supply_chain', 'schema', 'supply_sql_master.inventory', 'confidential', NULL, 'FEDERATED'),
  ('AZURE', 'supply_chain', 'schema', 'supply_sql_master.orders', 'confidential', NULL, 'FEDERATED'),
  ('GCP', 'marketing', 'external_location', 'loc_mktg_managed', NULL, NULL, NULL),
  ('GCP', 'marketing', 'external_location', 'loc_mktg_assets', NULL, NULL, NULL),
  ('GCP', 'marketing', 'catalog', 'marketing_gcp', NULL, 'marketing_scientists', 'MANAGED'),
  ('GCP', 'marketing', 'schema', 'marketing_gcp.intelligence', 'confidential', NULL, 'MANAGED'),
  ('GCP', 'marketing', 'volume', 'marketing_gcp.intelligence.campaign_assets', 'confidential', NULL, 'MANAGED'),
  ('GCP', 'marketing', 'volume', 'marketing_gcp.intelligence.ml_models_artifacts', 'confidential', NULL, 'MANAGED'),
  ('GCP', 'marketing', 'catalog', 'marketing_bq_fed', NULL, 'marketing_scientists', 'FEDERATED'),
  ('GCP', 'marketing', 'schema', 'marketing_bq_fed.analytics', 'internal', NULL, 'FEDERATED'),
  ('GCP', 'marketing', 'schema', 'marketing_bq_fed.web', 'pii', NULL, 'FEDERATED');

CREATE OR REPLACE TABLE platform_governance.catalog.access_matrix (
  cloud STRING, domain STRING, object_type STRING, object STRING,
  principal STRING, privileges STRING, classification STRING, reads_data BOOLEAN
);
INSERT INTO platform_governance.catalog.access_matrix (cloud, domain, object_type, object, principal, privileges, classification, reads_data) VALUES
  ('AWS', 'sales', 'external_location', 'loc_sales_raw', 'data_engineers', 'ALL_PRIVILEGES', NULL, FALSE),
  ('AWS', 'sales', 'external_location', 'loc_sales_raw', 'data_scientists', 'READ_FILES', NULL, TRUE),
  ('AWS', 'sales', 'external_location', 'loc_sales_raw', 'metastore_admins', 'ALL_PRIVILEGES', NULL, FALSE),
  ('AWS', 'sales', 'external_location', 'loc_sales_managed', 'data_engineers', 'ALL_PRIVILEGES', NULL, FALSE),
  ('AWS', 'sales', 'external_location', 'loc_sales_managed', 'metastore_admins', 'ALL_PRIVILEGES', NULL, FALSE),
  ('AWS', 'sales', 'external_location', 'loc_sales_gold', 'data_engineers', 'ALL_PRIVILEGES', NULL, FALSE),
  ('AWS', 'sales', 'external_location', 'loc_sales_gold', 'analysts', 'READ_FILES', NULL, TRUE),
  ('AWS', 'sales', 'external_location', 'loc_sales_gold', 'business_users', 'READ_FILES', NULL, TRUE),
  ('AWS', 'sales', 'external_location', 'loc_sales_gold', 'metastore_admins', 'ALL_PRIVILEGES', NULL, FALSE),
  ('AWS', 'sales', 'catalog', 'sales_aws', 'data_engineers', 'USE_CATALOG, CREATE_SCHEMA', NULL, FALSE),
  ('AWS', 'sales', 'catalog', 'sales_aws', 'metastore_admins', 'ALL_PRIVILEGES', NULL, FALSE),
  ('AWS', 'sales', 'catalog', 'sales_rds_fed', 'data_engineers', 'USE_CATALOG', NULL, FALSE),
  ('AWS', 'sales', 'catalog', 'sales_rds_fed', 'metastore_admins', 'ALL_PRIVILEGES', NULL, FALSE),
  ('AWS', 'sales', 'schema', 'sales_aws.bronze', 'data_engineers', 'USE_SCHEMA, CREATE_TABLE, SELECT, MODIFY', 'confidential', TRUE),
  ('AWS', 'sales', 'schema', 'sales_aws.bronze', 'metastore_admins', 'ALL_PRIVILEGES', 'confidential', FALSE),
  ('AWS', 'sales', 'schema', 'sales_aws.silver', 'data_engineers', 'USE_SCHEMA, CREATE_TABLE, SELECT, MODIFY', 'confidential', TRUE),
  ('AWS', 'sales', 'schema', 'sales_aws.silver', 'data_scientists', 'USE_SCHEMA, SELECT', 'confidential', TRUE),
  ('AWS', 'sales', 'schema', 'sales_aws.silver', 'metastore_admins', 'ALL_PRIVILEGES', 'confidential', FALSE),
  ('AWS', 'sales', 'schema', 'sales_aws.gold', 'data_engineers', 'USE_SCHEMA, CREATE_TABLE, SELECT, MODIFY', 'internal', TRUE),
  ('AWS', 'sales', 'schema', 'sales_aws.gold', 'analysts', 'USE_SCHEMA, SELECT', 'internal', TRUE),
  ('AWS', 'sales', 'schema', 'sales_aws.gold', 'business_users', 'USE_SCHEMA, SELECT', 'internal', TRUE),
  ('AWS', 'sales', 'schema', 'sales_aws.gold', 'metastore_admins', 'ALL_PRIVILEGES', 'internal', FALSE),
  ('AWS', 'sales', 'schema', 'sales_rds_fed.orders', 'analysts', 'USE_SCHEMA, SELECT', 'confidential', TRUE),
  ('AWS', 'sales', 'schema', 'sales_rds_fed.orders', 'data_engineers', 'USE_SCHEMA, SELECT', 'confidential', TRUE),
  ('AWS', 'sales', 'schema', 'sales_rds_fed.orders', 'metastore_admins', 'ALL_PRIVILEGES', 'confidential', FALSE),
  ('AWS', 'sales', 'schema', 'sales_rds_fed.crm', 'crm_managers', 'USE_SCHEMA, SELECT', 'pii', TRUE),
  ('AWS', 'sales', 'schema', 'sales_rds_fed.crm', 'metastore_admins', 'ALL_PRIVILEGES', 'pii', FALSE),
  ('AWS', 'sales', 'volume', 'sales_aws.bronze.sales_landing_zone', 'data_engineers', 'READ_VOLUME, WRITE_VOLUME', 'confidential', TRUE),
  ('AWS', 'sales', 'volume', 'sales_aws.bronze.sales_landing_zone', 'metastore_admins', 'ALL_PRIVILEGES', 'confidential', FALSE),
  ('AZURE', 'supply_chain', 'external_location', 'loc_supply_raw', 'data_engineers', 'CREATE_EXTERNAL_TABLE, CREATE_EXTERNAL_VOLUME', NULL, FALSE),
  ('AZURE', 'supply_chain', 'external_location', 'loc_supply_raw', 'metastore_admins', 'ALL_PRIVILEGES', NULL, FALSE),
  ('AZURE', 'supply_chain', 'external_location', 'loc_supply_managed', 'data_engineers', 'ALL_PRIVILEGES', NULL, FALSE),
  ('AZURE', 'supply_chain', 'external_location', 'loc_supply_managed', 'metastore_admins', 'ALL_PRIVILEGES', NULL, FALSE),
  ('AZURE', 'supply_chain', 'catalog', 'supplies_azure', 'data_engineers', 'USE_CATALOG, CREATE_SCHEMA', NULL, FALSE),
  ('AZURE', 'supply_chain', 'catalog', 'supplies_azure', 'metastore_admins', 'ALL_PRIVILEGES', NULL, FALSE),
  ('AZURE', 'supply_chain', 'catalog', 'supply_sql_master', 'data_engineers', 'USE_CATALOG', NULL, FALSE),
  ('AZURE', 'supply_chain', 'catalog', 'supply_sql_master', 'metastore_admins', 'ALL_PRIVILEGES', NULL, FALSE),
  ('AZURE', 'supply_chain', 'schema', 'supplies_azure.bronze', 'data_engineers', 'USE_SCHEMA, CREATE_TABLE, SELECT, MODIFY', 'confidential', TRUE),
  ('AZURE', 'supply_chain', 'schema', 'supplies_azure.bronze', 'metastore_admins', 'ALL_PRIVILEGES', 'confidential', FALSE),
  ('AZURE', 'supply_chain', 'schema', 'supplies_azure.silver', 'data_engineers', 'USE_SCHEMA, CREATE_TABLE, SELECT, MODIFY', 'confidential', TRUE),
  ('AZURE', 'supply_chain', 'schema', 'supplies_azure.silver', 'data_scientists', 'USE_SCHEMA, SELECT', 'confidential', TRUE),
  ('AZURE', 'supply_chain', 'schema', 'supplies_azure.silver', 'metastore_admins', 'ALL_PRIVILEGES', 'confidential', FALSE),
  ('AZURE', 'supply_chain', 'schema', 'supply_sql_master.inventory', 'data_scientists', 'USE_SCHEMA, SELECT', 'confidential', TRUE),
  ('AZURE', 'supply_chain', 'schema', 'supply_sql_master.inventory', 'metastore_admins', 'ALL_PRIVILEGES', 'confidential', FALSE),
  ('AZURE', 'supply_chain', 'schema', 'supply_sql_master.orders', 'analysts', 'USE_SCHEMA, SELECT', 'confidential', TRUE),
  ('AZURE', 'supply_chain', 'schema', 'supply_sql_master.orders', 'metastore_admins', 'ALL_PRIVILEGES', 'confidential', FALSE),
  ('AZURE', 'supply_chain', 'volume', 'supplies_azure.bronze.supplies_landing_zone', 'data_engineers', 'READ_VOLUME, WRITE_VOLUME', 'confidential', TRUE),
  ('AZURE', 'supply_chain', 'volume', 'supplies_azure.bronze.supplies_landing_zone', 'metastore_admins', 'ALL_PRIVILEGES', 'confidential', FALSE),
  ('GCP', 'marketing', 'external_location', 'loc_mktg_managed', 'data_engineers', 'ALL_PRIVILEGES', NULL, FALSE),
  ('GCP', 'marketing', 'external_location', 'loc_mktg_managed', 'metastore_admins', 'ALL_PRIVILEGES', NULL, FALSE),
  ('GCP', 'marketing', 'external_location', 'loc_mktg_assets', 'data_engineers', 'ALL_PRIVILEGES', NULL, FALSE),
  ('GCP', 'marketing', 'external_location', 'loc_mktg_assets', 'metastore_admins', 'ALL_PRIVILEGES', NULL, FALSE),
  ('GCP', 'marketing', 'catalog', 'marketing_gcp', 'data_engineers', 'USE_CATALOG, CREATE_SCHEMA', NULL, FALSE),
  ('GCP', 'marketing', 'catalog', 'marketing_gcp', 'metastore_admins', 'ALL_PRIVILEGES', NULL, FALSE),
  ('GCP', 'marketing', 'catalog', 'marketing_bq_fed', 'data_engineers', 'USE_CATALOG', NULL, FALSE),
  ('GCP', 'marketing', 'catalog', 'marketing_bq_fed', 'metastore_admins', 'ALL_PRIVILEGES', NULL, FALSE),
  ('GCP', 'marketing', 'schema', 'marketing_gcp.intelligence', 'marketing_analysts', 'USE_SCHEMA, SELECT', 'confidential', TRUE),
  ('GCP', 'marketing', 'schema', 'marketing_gcp.intelligence', 'metastore_admins', 'ALL_PRIVILEGES', 'confidential', FALSE),
  ('GCP', 'marketing', 'schema', 'marketing_bq_fed.analytics', 'marketing_analysts', 'USE_SCHEMA, SELECT', 'internal', TRUE),
  ('GCP', 'marketing', 'schema', 'marketing_bq_fed.analytics', 'metastore_admins', 'ALL_PRIVILEGES', 'internal', FALSE),
  ('GCP', 'marketing', 'schema', 'marketing_bq_fed.web', 'data_scientists', 'USE_SCHEMA, SELECT', 'pii', TRUE),
  ('GCP', 'marketing', 'schema', 'marketing_bq_fed.web', 'metastore_admins', 'ALL_PRIVILEGES', 'pii', FALSE),
  ('GCP', 'marketing', 'volume', 'marketing_gcp.intelligence.campaign_assets', 'marketing_analysts', 'READ_VOLUME', 'confidential', TRUE),
  ('GCP', 'marketing', 'volume', 'marketing_gcp.intelligence.campaign_assets', 'metastore_admins', 'ALL_PRIVILEGES', 'confidential', FALSE),
  ('GCP', 'marketing', 'volume', 'marketing_gcp.intelligence.ml_models_artifacts', 'marketing_scientists', 'READ_VOLUME, WRITE_VOLUME', 'confidential', TRUE),
  ('GCP', 'marketing', 'volume', 'marketing_gcp.intelligence.ml_models_artifacts', 'metastore_admins', 'ALL_PRIVILEGES', 'confidential', FALSE);

CREATE OR REPLACE TABLE platform_governance.catalog.pii_map (
  cloud STRING, domain STRING, object STRING, storage STRING, readers STRING
);
INSERT INTO platform_governance.catalog.pii_map (cloud, domain, object, storage, readers) VALUES
  ('AWS', 'sales', 'sales_rds_fed.crm', 'federated', 'crm_managers'),
  ('GCP', 'marketing', 'marketing_bq_fed.web', 'federated', 'data_scientists');

CREATE OR REPLACE TABLE platform_governance.catalog.policy_findings (
  rule STRING, severity STRING, cloud STRING, object STRING, principal STRING,
  message STRING, dimension STRING, accepted BOOLEAN, justification STRING
);
INSERT INTO platform_governance.catalog.policy_findings (rule, severity, cloud, object, principal, message, dimension, accepted, justification) VALUES
  ('PII_BROAD_READ', 'HIGH', 'AWS', 'schema:sales_rds_fed.crm', 'crm_managers', 'PII is readable by a non-admin principal not on the PII allowlist', 'Data quality & lineage', TRUE, 'CRM operations team requires read access to customer records to service accounts. Access is read-only (SELECT), scoped to the crm_managers group, and covered by DPIA-2026-014.'),
  ('PII_BROAD_READ', 'HIGH', 'GCP', 'schema:marketing_bq_fed.web', 'data_scientists', 'PII is readable by a non-admin principal not on the PII allowlist', 'Data quality & lineage', TRUE, 'Web analytics PII is pseudonymised at source; data scientists use it for aggregate modelling only. Accepted risk pending the migration to a fully anonymised feature view (tracked in DPIA-2026-021).'),
  ('ALL_PRIVILEGES_NONADMIN', 'MEDIUM', 'AWS', 'external_location:loc_sales_gold', 'data_engineers', 'ALL_PRIVILEGES granted to a non-admin, non-owner principal', 'Governance as code', FALSE, ''),
  ('ALL_PRIVILEGES_NONADMIN', 'MEDIUM', 'AWS', 'external_location:loc_sales_managed', 'data_engineers', 'ALL_PRIVILEGES granted to a non-admin, non-owner principal', 'Governance as code', FALSE, ''),
  ('ALL_PRIVILEGES_NONADMIN', 'MEDIUM', 'AWS', 'external_location:loc_sales_raw', 'data_engineers', 'ALL_PRIVILEGES granted to a non-admin, non-owner principal', 'Governance as code', FALSE, ''),
  ('ALL_PRIVILEGES_NONADMIN', 'MEDIUM', 'AZURE', 'external_location:loc_supply_managed', 'data_engineers', 'ALL_PRIVILEGES granted to a non-admin, non-owner principal', 'Governance as code', FALSE, ''),
  ('ALL_PRIVILEGES_NONADMIN', 'MEDIUM', 'GCP', 'external_location:loc_mktg_assets', 'data_engineers', 'ALL_PRIVILEGES granted to a non-admin, non-owner principal', 'Governance as code', FALSE, ''),
  ('ALL_PRIVILEGES_NONADMIN', 'MEDIUM', 'GCP', 'external_location:loc_mktg_managed', 'data_engineers', 'ALL_PRIVILEGES granted to a non-admin, non-owner principal', 'Governance as code', FALSE, ''),
  ('FEDERATED_PII', 'INFO', 'AWS', 'schema:sales_rds_fed.crm', '', 'PII resides in a federated source (outside Unity Catalog managed storage)', 'Data quality & lineage', FALSE, ''),
  ('FEDERATED_PII', 'INFO', 'GCP', 'schema:marketing_bq_fed.web', '', 'PII resides in a federated source (outside Unity Catalog managed storage)', 'Data quality & lineage', FALSE, '');

