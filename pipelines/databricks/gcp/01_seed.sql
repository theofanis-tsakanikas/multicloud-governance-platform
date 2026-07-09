-- ============================================================================
-- GCP · 01 SEED  ·  region-aligned raw marketing web data (with PII)
-- Runs on the GCP workspace (marketing_gcp lives in the GCP metastore).
-- Shared region dimension: EU-North · EU-South · EU-East · EU-West
-- ============================================================================
CREATE OR REPLACE TABLE marketing_gcp.intelligence.web_raw AS
SELECT
  concat('sess_', lpad(cast(id AS STRING), 7, '0'))                                     AS session_id,
  element_at(array('EU-North','EU-South','EU-East','EU-West'), cast(rand()*4 AS INT)+1) AS region,
  concat('visitor', cast(rand()*99999 AS INT), '@example.com')                          AS user_email,   -- PII
  concat('10.', cast(rand()*255 AS INT), '.', cast(rand()*255 AS INT), '.', cast(rand()*254 AS INT)+1) AS ip_address, -- PII
  concat('camp_', cast(rand()*30 AS INT))                                               AS campaign_id,
  round(rand()*90 + 1, 2)                                                               AS spend,
  date_add(current_date(), -cast(rand()*90 AS INT))                                     AS event_date
FROM range(20000) AS t(id);
