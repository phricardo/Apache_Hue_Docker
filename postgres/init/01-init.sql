CREATE DATABASE hue_source;

\connect hue_source

CREATE TABLE IF NOT EXISTS sample_sales (
  id SERIAL PRIMARY KEY,
  customer_name VARCHAR(100) NOT NULL,
  amount NUMERIC(12,2) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO sample_sales (customer_name, amount)
VALUES
  ('Acme', 1299.90),
  ('Globex', 845.50),
  ('Initech', 4120.00);