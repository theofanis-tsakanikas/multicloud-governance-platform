# Databricks notebook source
# MAGIC %md
# MAGIC # 🔒 Private Connectivity — the proof, live
# MAGIC
# MAGIC Three databases. Three clouds. **Not one of them is reachable from the public internet.**
# MAGIC And this workspace queries all three.
# MAGIC
# MAGIC | | Source | How it is reached | What makes it private |
# MAGIC |---|---|---|---|
# MAGIC | 🟠 | **AWS** · RDS Postgres | NCC → PrivateLink → NLB → Fargate `pgbouncer` → RDS Proxy | `publicly_accessible = false` — **the instance has no public address at all** |
# MAGIC | 🔷 | **Azure** · Azure SQL | NCC → PrivateLink → NLB → Fargate `HAProxy` → **IPsec VPN** → private endpoint | `publicNetworkAccess = Disabled` — **the server refuses the internet** |
# MAGIC | 🔵 | **GCP** · BigQuery | NCC → PrivateLink → NLB → Fargate `HAProxy` → **IPsec VPN** → `private.googleapis.com` VIP | The connection never leaves private address space |
# MAGIC
# MAGIC Databricks serverless runs in **AWS**, and an NCC private-endpoint rule can only ever create an
# MAGIC **AWS** endpoint. So Azure and GCP are reached the only way they can be: a *transit hub* — an AWS
# MAGIC PrivateLink service in front of a proxy that carries the connection across a VPN into the other cloud.
# MAGIC
# MAGIC > **Honest footnote for GCP:** BigQuery is a Google-managed API — there is no
# MAGIC > "disable public access" switch to flip, the way there is on RDS and Azure SQL. What is private
# MAGIC > here is the **connection**: it travels through Google's private API VIP and never touches the
# MAGIC > internet. Removing BigQuery's public API surface entirely is VPC Service Controls, not this.

# COMMAND ----------
# MAGIC %md
# MAGIC ## ⚠️ Expect a `NULL` market in cells 1–3. It is supposed to be there.
# MAGIC
# MAGIC All three sources are seeded **deliberately dirty**, because real OLTP systems are — every 50th
# MAGIC row lost its market attribution (`market IS NULL`), alongside non-positive amounts, replayed
# MAGIC duplicates, and orders whose customer was erased under GDPR. From the RDS seeder itself:
# MAGIC
# MAGIC > *"Deliberately DIRTY, because a real OLTP source is. Without this the medallion's
# MAGIC > bronze→silver step rejects zero rows and the 'cleansing' stage is theatre."*
# MAGIC
# MAGIC So watch that `NULL` travel:
# MAGIC
# MAGIC | | |
# MAGIC |---|---|
# MAGIC | **Cells 1–3** — the raw private sources | 6 markets **+ NULL** ← the truth, as it is |
# MAGIC | **Cell 4** — the three-cloud join | 6 markets, no NULL — `NULL` never joins to anything |
# MAGIC | **Cell 5** — the governed gold | 6 markets, no NULL — the quality gate refused it |
# MAGIC | **Cell 6** — the rejects | `null_market: 120` ← there it is, counted, not lost |
# MAGIC
# MAGIC The private connection's job is to deliver the truth, not a convenient version of it.
# MAGIC Deciding which of that truth reaches a CEO's report is governance's job — and it shows its work.

# COMMAND ----------
# MAGIC %md
# MAGIC ## 1 · 🟠 AWS — RDS Postgres, which has no public IP
# MAGIC The instance is `publicly_accessible = false`. There is no address to dial from outside the VPC.
# MAGIC Every row below crossed a PrivateLink endpoint and a `pgbouncer` running on Fargate.

# COMMAND ----------
# MAGIC %sql
# MAGIC SELECT market,
# MAGIC        COUNT(*)          AS orders,
# MAGIC        ROUND(SUM(amount)) AS revenue
# MAGIC FROM   sales_rds_fed.orders.orders      -- 🔒 private RDS, live
# MAGIC GROUP  BY market
# MAGIC ORDER  BY revenue DESC;

# COMMAND ----------
# MAGIC %md
# MAGIC ## 2 · 🔷 Azure — Azure SQL, which refuses the internet
# MAGIC `publicNetworkAccess = Disabled`. This answer crossed a PrivateLink service, an HAProxy on
# MAGIC Fargate, an **IPsec tunnel into Azure**, and a private endpoint — in that order.

# COMMAND ----------
# MAGIC %sql
# MAGIC SELECT market,
# MAGIC        COUNT(*)             AS purchase_orders,
# MAGIC        SUM(units)           AS units_ordered,
# MAGIC        ROUND(AVG(lead_days), 1) AS avg_lead_days
# MAGIC FROM   supply_sql_master.orders.purchase_orders   -- 🔒 private Azure SQL, live, across a VPN
# MAGIC GROUP  BY market
# MAGIC ORDER  BY avg_lead_days DESC;

# COMMAND ----------
# MAGIC %md
# MAGIC ## 3 · 🔵 GCP — BigQuery, reached without touching the internet
# MAGIC The gateway dials `199.36.153.8/30` — Google's **private API VIP** — by address, across an IPsec
# MAGIC tunnel into a GCP VPC. No DNS, no public route. The TLS session is end-to-end: the proxy carries
# MAGIC bytes it cannot read.

# COMMAND ----------
# MAGIC %sql
# MAGIC SELECT market,
# MAGIC        COUNT(*)          AS sessions,
# MAGIC        ROUND(SUM(spend)) AS marketing_spend
# MAGIC FROM   marketing_bq_fed.analytics.sessions   -- 🔒 private BigQuery, live, via the Google VIP
# MAGIC GROUP  BY market
# MAGIC ORDER  BY marketing_spend DESC;

# COMMAND ----------
# MAGIC %md
# MAGIC ## 4 · 🎯 All three at once — **one statement, three clouds, three private paths**
# MAGIC
# MAGIC This is the whole architecture in a single query. The optimiser pushes three aggregations down
# MAGIC into three different engines, in three different clouds, over three different private circuits —
# MAGIC and joins the results here.
# MAGIC
# MAGIC > 🗣️ *"Revenue comes from a Postgres with no public IP. Spend comes from a BigQuery I reach through
# MAGIC > a tunnel. Lead times come from a SQL Server that refuses the internet. One query. No public
# MAGIC > endpoint anywhere in it."*
# MAGIC
# MAGIC 📊 *After it runs: **+ Visualization** → Bar, x = `market`, y = `revenue`, colour by `marketing_roi`.*

# COMMAND ----------
# MAGIC %sql
# MAGIC WITH aws_sales AS (            -- 🟠 AWS · RDS Postgres  (publicly_accessible = false)
# MAGIC   SELECT market,
# MAGIC          ROUND(SUM(amount)) AS revenue,
# MAGIC          COUNT(*)           AS orders
# MAGIC   FROM   sales_rds_fed.orders.orders
# MAGIC   GROUP  BY market
# MAGIC ),
# MAGIC gcp_marketing AS (            -- 🔵 GCP · BigQuery      (via private.googleapis.com, over a VPN)
# MAGIC   SELECT market,
# MAGIC          ROUND(SUM(spend)) AS marketing_spend,
# MAGIC          COUNT(*)          AS sessions
# MAGIC   FROM   marketing_bq_fed.analytics.sessions
# MAGIC   GROUP  BY market
# MAGIC ),
# MAGIC azure_supply AS (             -- 🔷 Azure · Azure SQL   (publicNetworkAccess = Disabled, over a VPN)
# MAGIC   SELECT market,
# MAGIC          ROUND(AVG(lead_days), 1) AS avg_lead_days,
# MAGIC          SUM(units)               AS units_ordered
# MAGIC   FROM   supply_sql_master.orders.purchase_orders
# MAGIC   GROUP  BY market
# MAGIC )
# MAGIC SELECT s.market,
# MAGIC        g.marketing_spend,
# MAGIC        s.revenue,
# MAGIC        ROUND(s.revenue / NULLIF(g.marketing_spend, 0), 2) AS marketing_roi,
# MAGIC        a.avg_lead_days,
# MAGIC        a.units_ordered
# MAGIC FROM   aws_sales     AS s
# MAGIC JOIN   gcp_marketing AS g   ON g.market = s.market
# MAGIC JOIN   azure_supply  AS a   ON a.market = s.market
# MAGIC ORDER  BY s.revenue DESC;

# COMMAND ----------
# MAGIC %md
# MAGIC ## 5 · The same three sources, **governed** — and why the number is smaller
# MAGIC
# MAGIC Cell 4 read the three private sources *raw*. This is what the **pipeline** built from those same
# MAGIC three sources: bronze → silver → gold, PII-minimised, published as a Delta table.
# MAGIC
# MAGIC **The revenue is lower here, and that is the point.** Germany is ~628k raw and ~622k governed.
# MAGIC The missing ~6k is not a bug — it is every row the quality gate refused: null markets,
# MAGIC non-positive amounts, replayed duplicates, orders whose customer does not exist.
# MAGIC
# MAGIC > 🗣️ *"The private connection gets me the data. The governance decides which of it is true."*
# MAGIC
# MAGIC Cell 6 shows exactly what was thrown away, and why.

# COMMAND ----------
# MAGIC %sql
# MAGIC SELECT market, marketing_spend, revenue, marketing_roi,
# MAGIC        avg_lead_days, inventory_units, stockout_risk
# MAGIC FROM   sales_aws.gold.executive_cross_cloud
# MAGIC ORDER  BY revenue DESC;

# COMMAND ----------
# MAGIC %md
# MAGIC ## 6 · The rows the gate refused — the difference, itemised

# COMMAND ----------
# MAGIC %sql
# MAGIC SELECT reason, rows
# MAGIC FROM   sales_aws.silver.sales_rejects
# MAGIC WHERE  rows > 0
# MAGIC ORDER  BY rows DESC;
# MAGIC -- 📊 BAR (x=reason, y=rows)

# COMMAND ----------
# MAGIC %md
# MAGIC ## 7 · Where the bytes actually went
# MAGIC
# MAGIC Every query above left a trace. The proxies log each TCP session — and a session that carries
# MAGIC **thousands of bytes** is a query; a session that carries **zero** is a health check.
# MAGIC
# MAGIC ```
# MAGIC CloudWatch → /ecs/bq-gateway-dev     10.11.2.165 → api_out/googleapi1   7156 bytes   ← cell 3 & 4
# MAGIC CloudWatch → /ecs/sql-gateway-dev    10.10.1.x   → sql_out/azuresql     4820 bytes   ← cell 2 & 4
# MAGIC ```
# MAGIC
# MAGIC The private path is not a claim in a diagram. It is a packet count.
