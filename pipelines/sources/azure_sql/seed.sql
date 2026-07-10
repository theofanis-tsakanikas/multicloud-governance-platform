-- ============================================================================
-- SIMULATED SOURCE SYSTEM · AZURE · SQL Server (sqldb-product-catalog)
--
-- Stands in for the ERP an operations team owns (ADR-0014). The governance
-- platform never runs this: it is the "application" writing its own tables, so
-- that `supply_sql_master` — the Lakehouse Federation catalog — has real rows to
-- expose instead of empty schemas.
--
-- The two schemas already exist (storage/mssql_schemas layer). This adds tables.
--
-- Deterministic: no RAND(), no GETDATE(). Everything derives from a row number,
-- so every run produces identical data and re-running is idempotent.
--
-- ── Why two schemas ────────────────────────────────────────────────────────
--   inventory.stock            what is on the shelf, per SKU and market
--   orders.purchase_orders     what is in transit, per shipment
--
-- The medallion joins them ACROSS the two federated schemas, in one query, from
-- Databricks — which is the point of federating rather than copying.
--
-- ── The market asymmetry ───────────────────────────────────────────────────
-- Poland has the longest lead times and the thinnest stock. That is not noise:
-- it is what makes `stockout_risk` in 03_executive.sql a finding rather than a
-- flat column. See pipelines/sources/rds/seed.sql for the revenue side.
--
--   Netherlands  6d   Germany  8d   France  9d   Spain 14d   Italy 17d   Poland 23d
--
-- No PII lives here. Supply chain data is `confidential`, not `pii`.
-- ============================================================================

IF OBJECT_ID('orders.purchase_orders', 'U') IS NOT NULL DROP TABLE orders.purchase_orders;
IF OBJECT_ID('inventory.stock', 'U') IS NOT NULL DROP TABLE inventory.stock;

-- ────────────────────────────────────────────────────────── inventory.stock
-- One row per (SKU, market): 6 markets x 4 SKUs = 24.
CREATE TABLE inventory.stock (
    sku            VARCHAR(16)  NOT NULL,
    market         VARCHAR(32)  NOT NULL,
    on_hand        INT          NOT NULL,
    reorder_point  INT          NOT NULL,
    updated_on     DATE         NOT NULL,
    CONSTRAINT pk_stock PRIMARY KEY (sku, market)
);

;WITH n AS (
    SELECT 1 AS i UNION ALL SELECT i + 1 FROM n WHERE i < 24
),
grid AS (
    SELECT
        i,
        CONCAT('SKU-', CHAR(65 + ((i - 1) % 4))) AS sku,          -- SKU-A .. SKU-D
        CASE (i - 1) / 4
            WHEN 0 THEN 'Germany'
            WHEN 1 THEN 'France'
            WHEN 2 THEN 'Netherlands'
            WHEN 3 THEN 'Spain'
            WHEN 4 THEN 'Italy'
            ELSE        'Poland'
        END AS market
    FROM n
)
INSERT INTO inventory.stock (sku, market, on_hand, reorder_point, updated_on)
SELECT
    sku,
    market,
    -- Poland runs thin: on_hand lands below the reorder band. Everywhere else it
    -- starts well above it.
    CASE WHEN market = 'Poland'
         THEN 40 + ((i * 37) % 120)          --  40 ..  159
         ELSE 600 + ((i * 131) % 1400)       -- 600 .. 1999
    END,
    120 + ((i * 53) % 180),                  -- 120 ..  299
    DATEADD(DAY, -(i % 30), CAST('2026-07-01' AS DATE))
FROM grid
OPTION (MAXRECURSION 0);

-- ──────────────────────────────────────────────── orders.purchase_orders
--
-- Deliberately DIRTY, because a real ERP is:
--
--   market IS NULL   every 50th order  (~80)  -> the PO never got a destination
--   units <= 0       every 97th order  (~41)  -> returns and cancellations
--   duplicate rows   40 replays              -> the ERP re-sends on retry
--
-- No primary key on po_id: de-duplication is the lakehouse's job, not the ERP's.
CREATE TABLE orders.purchase_orders (
    po_id        VARCHAR(16)  NOT NULL,
    supplier_id  VARCHAR(16)  NOT NULL,
    sku          VARCHAR(16)  NOT NULL,
    market       VARCHAR(32)  NULL,       -- nullable: the source does not guarantee it
    units        INT          NOT NULL,   -- may be <= 0 (return / cancellation)
    lead_days    INT          NOT NULL,
    ship_date    DATE         NOT NULL
);

;WITH n AS (
    SELECT 1 AS i UNION ALL SELECT i + 1 FROM n WHERE i < 4000
),
base AS (
    SELECT
        i,
        -- Same 30/22/15/13/12/8 weighting the sales source uses, so a market's
        -- supply volume matches its commercial size.
        CASE
            WHEN i % 100 <  30 THEN 'Germany'
            WHEN i % 100 <  52 THEN 'France'
            WHEN i % 100 <  67 THEN 'Netherlands'
            WHEN i % 100 <  80 THEN 'Spain'
            WHEN i % 100 <  92 THEN 'Italy'
            ELSE                    'Poland'
        END AS mkt
    FROM n
)
INSERT INTO orders.purchase_orders (po_id, supplier_id, sku, market, units, lead_days, ship_date)
SELECT
    CONCAT('po_', RIGHT(CONCAT('000000', CAST(i AS VARCHAR(8))), 6)),
    CONCAT('sup_', CAST(i % 40 AS VARCHAR(4))),
    CONCAT('SKU-', CHAR(65 + (i % 4))),
    CASE WHEN i % 50 = 0 THEN NULL ELSE mkt END,
    CASE WHEN i % 97 = 0
         THEN -1 * (10 + (i % 40))            -- return
         ELSE 20 + ((i * 131) % 480)
    END,
    -- Base lead time per market + 0..5 days of deterministic jitter.
    CASE mkt
        WHEN 'Netherlands' THEN 6
        WHEN 'Germany'     THEN 8
        WHEN 'France'      THEN 9
        WHEN 'Spain'       THEN 14
        WHEN 'Italy'       THEN 17
        ELSE                    23   -- Poland
    END + ((i * 17) % 6),
    DATEADD(DAY, -(i % 90), CAST('2026-07-10' AS DATE))
FROM base
OPTION (MAXRECURSION 0);

-- Replayed purchase orders: the same 40 rows arrive twice. DISTINCT collapses them.
INSERT INTO orders.purchase_orders
SELECT TOP (40) * FROM orders.purchase_orders ORDER BY po_id;

CREATE INDEX ix_po_market ON orders.purchase_orders (market);
CREATE INDEX ix_po_sku ON orders.purchase_orders (sku);
