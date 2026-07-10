-- ============================================================================
-- SIMULATED SOURCE SYSTEM · AWS · Postgres (RDS)
--
-- Stands in for the OLTP database an application team owns (ADR-0014). The
-- governance platform never runs this: it is the "application" writing its own
-- tables, so that `sales_rds_fed` — the Lakehouse Federation catalog — has real
-- rows to expose instead of empty schemas.
--
-- The two schemas already exist (storage/rds_schemas layer). This adds tables.
--
-- Deterministic: no random(), no now(). Seeded from generate_series so every run
-- produces byte-identical data and re-running is idempotent (DROP + CREATE).
--
-- Region dimension is shared with the Azure/GCP seeds: EU-North/South/East/West.
--
-- PII LIVES HERE AND ONLY HERE.
--   crm.customers   -> declared `pii`          (email, phone, full_name)
--   orders.orders   -> declared `confidential` (no PII; customer_id is a pseudonym)
-- The medallion ingests ONLY `orders`, and joins `crm` for non-identifying
-- attributes. No email/phone/name is ever copied into managed storage.
-- ============================================================================

-- ---------------------------------------------------------------- crm (PII)
DROP TABLE IF EXISTS crm.customers CASCADE;

CREATE TABLE crm.customers (
    customer_id  TEXT PRIMARY KEY,
    full_name    TEXT NOT NULL,   -- PII
    email        TEXT NOT NULL,   -- PII
    phone        TEXT NOT NULL,   -- PII
    country      TEXT NOT NULL,
    segment      TEXT NOT NULL,
    signup_date  DATE NOT NULL
);

INSERT INTO crm.customers (customer_id, full_name, email, phone, country, segment, signup_date)
SELECT
    'cust_' || lpad(i::TEXT, 5, '0'),
    'Customer ' || i,
    'customer' || i || '@example.com',
    '+3069' || lpad((10000000 + i)::TEXT, 8, '0'),
    (ARRAY['EU-North','EU-South','EU-East','EU-West'])[1 + (i % 4)],
    -- Deterministic segmentation: the business dimension gold aggregates on.
    (ARRAY['enterprise','mid_market','smb'])[1 + (i % 3)],
    DATE '2023-01-01' + ((i * 7) % 900)
FROM generate_series(1, 800) AS s(i);

-- ------------------------------------------------------- orders (no PII)
--
-- Deliberately DIRTY, because a real OLTP source is. Without this the medallion's
-- bronze->silver step rejects zero rows and the "cleansing" stage is theatre.
-- No primary key on order_id: the source re-sends orders, and de-duplication is
-- the lakehouse's job, not the source's.
--
--   region IS NULL      · every 50th order  (~120)  -> checkout never resolved the region
--   amount <= 0         · every 97th order  (~61)   -> refunds and cancellations
--   orphan customer_id  · every 211th order (~28)   -> customer deleted (GDPR erasure)
--   duplicate rows      · 40 replays of the first 40 orders
--
-- Each rule is deterministic, so the reject counts are identical on every run and
-- the medallion's data-quality numbers are reproducible.
DROP TABLE IF EXISTS orders.orders CASCADE;

CREATE TABLE orders.orders (
    order_id     TEXT NOT NULL,
    customer_id  TEXT NOT NULL,
    region       TEXT,                    -- nullable: the source does not guarantee it
    product_sku  TEXT NOT NULL,
    amount       NUMERIC(10, 2) NOT NULL, -- may be <= 0 (refund / cancellation)
    order_date   DATE NOT NULL
);

INSERT INTO orders.orders (order_id, customer_id, region, product_sku, amount, order_date)
SELECT
    'ord_' || lpad(i::TEXT, 6, '0'),
    CASE WHEN i % 211 = 0
         THEN 'cust_99999'                                    -- orphan: no such customer
         ELSE 'cust_' || lpad((1 + (i * 37) % 800)::TEXT, 5, '0')
    END,
    CASE WHEN i % 50 = 0
         THEN NULL                                            -- unresolved region
         ELSE (ARRAY['EU-North','EU-South','EU-East','EU-West'])[1 + (i % 4)]
    END,
    (ARRAY['SKU-A','SKU-B','SKU-C','SKU-D'])[1 + (i % 4)],
    CASE WHEN i % 97 = 0
         THEN -1 * ROUND((20 + ((i * 131) % 500))::NUMERIC, 2) -- refund
         -- 20.00 .. 1999.99, deterministic but not uniform across regions/SKUs.
         ELSE ROUND((20 + ((i * 131) % 1980) + ((i % 7) * 0.13))::NUMERIC, 2)
    END,
    DATE '2026-04-11' + (i % 90)
FROM generate_series(1, 6000) AS s(i);

-- Replayed orders: the same 40 rows arrive twice. DISTINCT in silver collapses them.
INSERT INTO orders.orders
SELECT * FROM orders.orders WHERE order_id <= 'ord_000040' ORDER BY order_id LIMIT 40;

CREATE INDEX ON orders.orders (customer_id);
CREATE INDEX ON orders.orders (region);

-- The federated catalog is read-only from Unity Catalog, so the reader needs
-- nothing beyond SELECT. sales_admin owns both schemas.
