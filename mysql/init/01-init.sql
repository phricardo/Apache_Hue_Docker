USE hue_source;

CREATE TABLE IF NOT EXISTS sample_orders (
  id INT AUTO_INCREMENT PRIMARY KEY,
  customer_name VARCHAR(100) NOT NULL,
  total_amount DECIMAL(12,2) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO sample_orders (customer_name, total_amount)
VALUES
  ('Wayne Enterprises', 999.99),
  ('Stark Industries', 1520.75),
  ('Umbrella Corp', 430.10);