CREATE DATABASE IF NOT EXISTS hue_impala_lab;

USE hue_impala_lab;

CREATE TABLE IF NOT EXISTS sample_events (
  id INT,
  customer_name STRING,
  amount DECIMAL(12,2),
  created_at STRING
)
STORED AS PARQUET;

INSERT INTO sample_events VALUES
  (1, 'Acme', 1299.90, '2026-04-09 10:00:00'),
  (2, 'Globex', 845.50, '2026-04-09 11:00:00'),
  (3, 'Initech', 4120.00, '2026-04-09 12:00:00');
