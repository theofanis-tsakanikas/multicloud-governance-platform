# Databricks notebook source
# MAGIC %md
# MAGIC # 🎬 Results — Gold-table queries for the recording
# MAGIC
# MAGIC **This notebook does NOT build anything** — the pipeline (the Asset Bundle
# MAGIC Job `medallion_aws`/`medallion_gcp`) already created the gold tables. Here we
# MAGIC just **query the existing gold tables** to show results, cell-by-cell.
# MAGIC
# MAGIC > After each query click **+ Visualization** and pick the chart noted.
# MAGIC > Deployed into your workspace by `databricks bundle deploy` — just open & play.

# COMMAND ----------
# MAGIC %md ## 1 · Revenue by region  (AWS sales gold)
# COMMAND ----------
# MAGIC %sql
# MAGIC SELECT region, revenue, orders, customers
# MAGIC FROM sales_aws.gold.sales_by_region
# MAGIC ORDER BY revenue DESC;
# MAGIC -- 📊 BAR (x=region, y=revenue)

# COMMAND ----------
# MAGIC %md ## 2 · 🔗 Marketing demand — Delta-shared from GCP, queried on AWS
# COMMAND ----------
# MAGIC %sql
# MAGIC SELECT region, marketing_spend, sessions, campaigns
# MAGIC FROM marketing_share.marketing_gcp.gold_marketing_by_region   -- DELTA-SHARED from GCP
# MAGIC ORDER BY marketing_spend DESC;
# MAGIC -- 📊 BAR (x=region, y=marketing_spend)

# COMMAND ----------
# MAGIC %md ## 3 · 🎯 THE Executive Cross-Cloud View — three clouds, one table
# COMMAND ----------
# MAGIC %sql
# MAGIC SELECT region, marketing_spend, revenue, marketing_roi,
# MAGIC        avg_lead_days, inventory_units, stockout_risk
# MAGIC FROM sales_aws.gold.executive_cross_cloud
# MAGIC ORDER BY revenue DESC;
# MAGIC -- 📊 TABLE (colour `stockout_risk`)  +  a BAR of revenue by region
# MAGIC -- 🗣️ "Region X: strong demand (GCP) → revenue (AWS), but supply lead times
# MAGIC --     high & inventory low (Azure) → stockout risk."

# COMMAND ----------
# MAGIC %md ## 4 · Marketing ROI — is demand turning into profit?
# COMMAND ----------
# MAGIC %sql
# MAGIC SELECT region, marketing_spend, revenue, marketing_roi
# MAGIC FROM sales_aws.gold.executive_cross_cloud
# MAGIC ORDER BY marketing_roi DESC;
# MAGIC -- 📊 BAR (x=region, y=marketing_roi)

# COMMAND ----------
# MAGIC %md ## 5 · Supply risk — where can we not deliver?
# COMMAND ----------
# MAGIC %sql
# MAGIC SELECT region, avg_lead_days, below_reorder_pct, stockout_risk
# MAGIC FROM sales_aws.gold.executive_cross_cloud
# MAGIC ORDER BY below_reorder_pct DESC;
# MAGIC -- 📊 TABLE (colour stockout_risk)  or  BAR (x=region, y=below_reorder_pct)

# COMMAND ----------
# MAGIC %md ## 6 · 🔒 Governance proof — the gold tables carry ZERO PII
# COMMAND ----------
# MAGIC %sql
# MAGIC -- Any email/phone/ip/name column anywhere in gold? Expect ZERO rows.
# MAGIC SELECT table_name, column_name
# MAGIC FROM sales_aws.information_schema.columns
# MAGIC WHERE table_schema = 'gold'
# MAGIC   AND lower(column_name) RLIKE 'email|phone|ip|ssn|name';

# COMMAND ----------
# MAGIC %md
# MAGIC ### …and neither does silver. The PII never entered the lakehouse at all.
# COMMAND ----------
# MAGIC %sql
# MAGIC -- Expect ZERO rows here too: silver holds a pseudonymous customer_id and a
# MAGIC -- segment, never an identity.
# MAGIC SELECT table_name, column_name
# MAGIC FROM sales_aws.information_schema.columns
# MAGIC WHERE table_schema = 'silver'
# MAGIC   AND lower(column_name) RLIKE 'email|phone|ssn|full_name';

# COMMAND ----------
# MAGIC %md
# MAGIC ### The identities exist — in the source system, queried in place
# MAGIC `sales_rds_fed` is a FEDERATED catalog over the live Postgres. Its `crm`
# MAGIC schema is classified `pii` and granted only to `crm_managers`. Nothing was
# MAGIC copied; Unity Catalog enforces the boundary at query time.
# COMMAND ----------
# MAGIC %sql
# MAGIC SELECT segment, count(*) AS customers   -- aggregate only; no identity leaves the source
# MAGIC FROM sales_rds_fed.crm.customers
# MAGIC GROUP BY segment ORDER BY customers DESC;
