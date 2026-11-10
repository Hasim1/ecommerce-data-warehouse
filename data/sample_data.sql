/* =====================================================================
   E-commerce Data Warehouse & BI Analytics
   ---------------------------------------------------------------------
   File    : data/sample_data.sql
   Engine  : PostgreSQL 13+
   Purpose : Loads realistic mock data into the star schema.

   What this script loads
   ----------------------
   1. dim_date            : every day from 2025-01-01 to 2026-12-31 (generated)
   2. dim_customer        : 20 customers across 18 countries
   3. dim_product         : 20 products across 5 categories
   4. dim_store           : 1 online store + 3 retail stores
   5. dim_payment_method  : 5 payment methods
   6. dim_shipping_method : 4 shipping methods
   7. fact_sales          : ~5,000 order lines covering the whole of 2025,
                            generated with:
                              - holiday seasonality (Nov/Dec peak, summer bump)
                              - weekend uplift
                              - skewed product popularity (some bestsellers)
                              - skewed customer activity (some heavy buyers)
                              - ~35% of lines discounted between 5% and 25%

   The generator uses setseed(), so the data is REPRODUCIBLE: the same
   PostgreSQL major version always produces the same numbers. (Use
   PostgreSQL 15+ for exact reproducibility across machines — version 15
   changed the random() algorithm, so 13/14 produce a different but
   statistically identical dataset.)

   Run AFTER schema/create_tables.sql.
   ===================================================================== */


/* =====================================================================
   1. dim_date — generate two full years of calendar days
   ===================================================================== */
INSERT INTO dim_date
      (date_key, full_date, year, quarter, month, month_name,
       day_of_month, day_of_week, day_name, week_of_year, is_weekend)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INT,                 -- smart key, e.g. 20250115
    d::DATE,
    EXTRACT(YEAR    FROM d)::INT,
    EXTRACT(QUARTER FROM d)::INT,
    EXTRACT(MONTH   FROM d)::INT,
    TRIM(TO_CHAR(d, 'Month')),                   -- 'January', 'February', ...
    EXTRACT(DAY     FROM d)::INT,
    EXTRACT(ISODOW  FROM d)::INT,                -- 1 = Monday ... 7 = Sunday
    TRIM(TO_CHAR(d, 'Day')),                     -- 'Monday', 'Tuesday', ...
    EXTRACT(WEEK    FROM d)::INT,
    EXTRACT(ISODOW  FROM d) IN (6, 7)            -- weekend flag
FROM generate_series('2025-01-01'::DATE, '2026-12-31'::DATE, INTERVAL '1 day') AS d;


/* =====================================================================
   2. dim_customer — 20 customers (surrogate keys 1..20 auto-assigned)
   ===================================================================== */
INSERT INTO dim_customer (customer_id, customer_name, email, city, country, customer_segment, signup_date) VALUES
('CUST-0001', 'Emma Müller',      'emma.mueller@example.com',    'Berlin',    'Germany',      'Consumer',       '2023-03-12'),
('CUST-0002', 'James Carter',     'james.carter@example.com',    'London',    'United Kingdom','Consumer',      '2022-11-05'),
('CUST-0003', 'Sophia Rossi',     'sophia.rossi@example.com',    'Milan',     'Italy',        'Consumer',       '2024-01-20'),
('CUST-0004', 'Ali Hassan',       'ali.hassan@example.com',      'Dubai',     'UAE',          'Corporate',      '2023-06-30'),
('CUST-0005', 'Fatima Khan',      'fatima.khan@example.com',     'Karachi',   'Pakistan',     'Consumer',       '2024-04-18'),
('CUST-0006', 'John Smith',       'john.smith@example.com',      'New York',  'USA',          'Small Business', '2022-08-14'),
('CUST-0007', 'Olivia Brown',     'olivia.brown@example.com',    'Toronto',   'Canada',       'Consumer',       '2023-09-02'),
('CUST-0008', 'Ahmed Mahmoud',    'ahmed.mahmoud@example.com',   'Cairo',     'Egypt',        'Consumer',       '2024-02-25'),
('CUST-0009', 'Chloé Dubois',     'chloe.dubois@example.com',    'Paris',     'France',       'Consumer',       '2023-12-01'),
('CUST-0010', 'Lucas Silva',      'lucas.silva@example.com',     'São Paulo', 'Brazil',       'Consumer',       '2024-05-09'),
('CUST-0011', 'Sara Al-Farsi',    'sara.alfarsi@example.com',    'Riyadh',    'Saudi Arabia', 'Corporate',      '2023-01-17'),
('CUST-0012', 'David Miller',     'david.miller@example.com',    'Chicago',   'USA',          'Consumer',       '2022-10-22'),
('CUST-0013', 'Anna Kowalska',    'anna.kowalska@example.com',   'Warsaw',    'Poland',       'Consumer',       '2024-03-08'),
('CUST-0014', 'Mehmet Yılmaz',    'mehmet.yilmaz@example.com',   'Istanbul',  'Turkey',       'Small Business', '2023-07-19'),
('CUST-0015', 'Grace Wilson',     'grace.wilson@example.com',    'Sydney',    'Australia',    'Consumer',       '2024-06-11'),
('CUST-0016', 'Hiro Tanaka',      'hiro.tanaka@example.com',     'Tokyo',     'Japan',        'Consumer',       '2023-04-27'),
('CUST-0017', 'Layla Ahmed',      'layla.ahmed@example.com',     'Amman',     'Jordan',       'Consumer',       '2024-08-03'),
('CUST-0018', 'Peter Schmidt',    'peter.schmidt@example.com',   'Munich',    'Germany',      'Corporate',      '2022-12-15'),
('CUST-0019', 'Isabella García',  'isabella.garcia@example.com', 'Madrid',    'Spain',        'Consumer',       '2023-10-29'),
('CUST-0020', 'Omar Farouk',      'omar.farouk@example.com',     'Doha',      'Qatar',        'Consumer',       '2024-07-21');


/* =====================================================================
   3. dim_product — 20 products in 5 categories (keys 1..20)
   ===================================================================== */
INSERT INTO dim_product (sku, product_name, category, subcategory, brand, unit_cost, list_price) VALUES
('EL-001', 'AeroBook 14 Laptop',            'Electronics',       'Computers',        'Novatech',   620.00, 899.99),
('EL-002', 'Pulse X Smartphone',            'Electronics',       'Phones',           'Novatech',   410.00, 649.99),
('EL-003', 'SoundCore Wireless Earbuds',    'Electronics',       'Audio',            'Audion',      28.00,  59.99),
('EL-004', 'UltraView 27" Monitor',         'Electronics',       'Monitors',         'ViewMax',    145.00, 249.99),
('EL-005', 'MechType Pro Keyboard',         'Electronics',       'Accessories',      'HyperKeys',   38.00,  89.99),
('EL-006', 'Portable Bluetooth Speaker',    'Electronics',       'Audio',            'Audion',      21.00,  49.99),
('HK-001', 'BrewMaster Coffee Machine',     'Home & Kitchen',    'Coffee & Tea',     'KitchenPro',  85.00, 179.99),
('HK-002', 'TurboBlend 900 Blender',        'Home & Kitchen',    'Small Appliances', 'KitchenPro',  32.00,  74.99),
('HK-003', '10-Piece Cookware Set',         'Home & Kitchen',    'Cookware',         'HomeChef',    70.00, 149.99),
('HK-004', 'RoboClean R7 Vacuum',           'Home & Kitchen',    'Cleaning',         'CleanTech',  190.00, 329.99),
('FA-001', 'Urban Runner Sneakers',         'Fashion',           'Shoes',            'Stride',      24.00,  79.99),
('FA-002', 'Classic Denim Jacket',          'Fashion',           'Outerwear',        'NorthLoom',   22.00,  64.99),
('FA-003', 'Slim Fit Jeans',                'Fashion',           'Clothing',         'NorthLoom',   14.00,  44.99),
('FA-004', 'Minimalist Steel Watch',        'Fashion',           'Accessories',      'Tempus',      55.00, 129.99),
('SP-001', 'EcoFlex Yoga Mat',              'Sports & Outdoors', 'Fitness',          'FitLife',      9.00,  29.99),
('SP-002', 'Adjustable Dumbbell Set 20kg',  'Sports & Outdoors', 'Fitness',          'IronCore',    48.00, 119.99),
('SP-003', 'Trail 2-Person Tent',           'Sports & Outdoors', 'Camping',          'CampRight',   62.00, 139.99),
('BH-001', 'HydraGlow Skincare Set',        'Beauty & Health',   'Skincare',         'Lumière',     18.00,  49.99),
('BH-002', 'IonPro Hair Dryer',             'Beauty & Health',   'Hair Care',        'GlamTech',    26.00,  69.99),
('BH-003', 'Electric Toothbrush S2',        'Beauty & Health',   'Oral Care',        'DentaFresh',  20.00,  54.99);


/* =====================================================================
   4. dim_store — one online channel + three retail locations
   ===================================================================== */
INSERT INTO dim_store (store_id, store_name, channel, city, country) VALUES
('ST-001', 'Online Store',        'Online', NULL,     'Global'),
('ST-002', 'Berlin Flagship',     'Retail', 'Berlin', 'Germany'),
('ST-003', 'Dubai Mall Outlet',   'Retail', 'Dubai',  'UAE'),
('ST-004', 'London Oxford St.',   'Retail', 'London', 'United Kingdom');


/* =====================================================================
   5. dim_payment_method
   ===================================================================== */
INSERT INTO dim_payment_method (payment_method_name) VALUES
('Credit Card'),
('Debit Card'),
('PayPal'),
('Cash on Delivery'),
('Bank Transfer');


/* =====================================================================
   6. dim_shipping_method
   ===================================================================== */
INSERT INTO dim_shipping_method (shipping_method_name, avg_delivery_days, base_fee) VALUES
('Standard',        5, 4.99),
('Express',         2, 9.99),
('Same-Day',        0, 14.99),
('In-Store Pickup', 0, 0.00);


/* =====================================================================
   7. fact_sales — generate ~5,000 realistic order lines for 2025
   ---------------------------------------------------------------------
   Step 7a: build a temporary table of ORDERS (order-level attributes:
            date, customer, store, payment, shipping, number of lines).
   Step 7b: explode each order into its ORDER LINES and roll the
            line-level attributes (product, quantity, discount).
   Step 7c: calculate all measures and insert into the fact table.

   NOTE on LATERAL + volatile functions: random() must live either in
   a top-level SELECT list (evaluated once per output row) or in a
   subquery/function call that REFERENCES the outer row. An independent
   subquery — even with the LATERAL keyword — is legally evaluated only
   ONCE by PostgreSQL and its result reused for every outer row.
   ===================================================================== */

-- Make the random generator deterministic → reproducible dataset
SELECT setseed(0.42);

-- ---- 7a. Orders ------------------------------------------------------
DROP TABLE IF EXISTS tmp_order;

CREATE TEMP TABLE tmp_order AS
WITH day_volume AS (
    -- Number of orders per day: base volume + seasonality + weekend uplift
    SELECT
        d::DATE AS order_date,
        (4                                                             -- base orders per day
         + CASE WHEN EXTRACT(MONTH FROM d) IN (11, 12) THEN 5          -- holiday season peak
                WHEN EXTRACT(MONTH FROM d) IN (6, 7)   THEN 2          -- summer bump
                ELSE 0 END
         + CASE WHEN EXTRACT(ISODOW FROM d) IN (6, 7)  THEN 2          -- weekend uplift
                ELSE 0 END
         + FLOOR(random() * 4)                                         -- day-to-day noise
        )::INT AS orders_today
    FROM generate_series('2025-01-01'::DATE, '2025-12-31'::DATE, INTERVAL '1 day') AS d
)
SELECT
    ROW_NUMBER() OVER (ORDER BY dv.order_date)                                        AS order_seq,
    dv.order_date,
    -- power() skews the distribution: low keys are picked more often,
    -- so some customers become "heavy buyers" (realistic for CLV analysis)
    (1 + FLOOR(POWER(random(), 1.5) * (SELECT COUNT(*) FROM dim_customer)))::INT      AS customer_key,
    (1 + FLOOR(random() * (SELECT COUNT(*) FROM dim_store)))::INT                     AS store_key,
    (1 + FLOOR(random() * (SELECT COUNT(*) FROM dim_payment_method)))::INT            AS payment_method_key,
    (1 + FLOOR(random() * (SELECT COUNT(*) FROM dim_shipping_method)))::INT           AS shipping_method_key,
    (1 + FLOOR(random() * 3))::INT                                                    AS lines_in_order
FROM day_volume dv
-- the argument references dv, so generate_series is re-evaluated per day
CROSS JOIN LATERAL generate_series(1, dv.orders_today) AS o;

-- ---- 7b. Explode orders into order lines -----------------------------
-- The generate_series argument references o.lines_in_order, so it is a
-- true LATERAL dependency and runs once per order. The random() picks
-- are in the top-level SELECT list, so they are rolled once per LINE.
DROP TABLE IF EXISTS tmp_line;

CREATE TEMP TABLE tmp_line AS
SELECT
    o.order_seq,
    o.order_date,
    o.customer_key,
    o.store_key,
    o.payment_method_key,
    o.shipping_method_key,
    line_no,
    -- POWER(random(),2) makes low product keys (electronics) more
    -- popular → clear bestsellers in the analysis
    (1 + FLOOR(POWER(random(), 2) * (SELECT COUNT(*) FROM dim_product)))::INT AS product_key,
    (1 + FLOOR(random() * 3))::INT                                            AS quantity,
    random()                                                                  AS discount_roll,
    random()                                                                  AS discount_rate_roll
FROM tmp_order o
CROSS JOIN LATERAL generate_series(1, o.lines_in_order) AS line_no;

-- ---- 7c. Calculate measures → fact_sales -----------------------------
INSERT INTO fact_sales
      (order_id, order_line, date_key, customer_key, product_key, store_key,
       payment_method_key, shipping_method_key,
       quantity, unit_price, unit_cost,
       discount_amount, gross_amount, total_amount, profit_amount)
SELECT
    'SO-2025-' || LPAD(l.order_seq::TEXT, 5, '0')          AS order_id,
    l.line_no                                               AS order_line,
    TO_CHAR(l.order_date, 'YYYYMMDD')::INT                  AS date_key,
    l.customer_key,
    l.product_key,
    l.store_key,
    l.payment_method_key,
    l.shipping_method_key,
    l.quantity,
    p.list_price                                            AS unit_price,   -- price at time of sale
    p.unit_cost,                                                             -- cost at time of sale
    dsc.discount_amount,
    g.gross_amount,
    g.gross_amount - dsc.discount_amount                    AS total_amount,
    g.gross_amount - dsc.discount_amount
        - l.quantity * p.unit_cost                          AS profit_amount
FROM tmp_line l
JOIN dim_product p ON p.product_key = l.product_key
-- these LATERALs reference outer columns (deterministic per-row
-- calculations), so they are just named intermediate results
CROSS JOIN LATERAL (
    SELECT (l.quantity * p.list_price)::NUMERIC(12,2) AS gross_amount
) AS g
CROSS JOIN LATERAL (
    -- ~35% of order lines get a discount between 5% and 25%
    SELECT (CASE
                WHEN l.discount_roll < 0.35
                THEN ROUND((g.gross_amount * (0.05 + l.discount_rate_roll * 0.20))::NUMERIC, 2)
                ELSE 0
            END)::NUMERIC(10,2) AS discount_amount
) AS dsc;

DROP TABLE IF EXISTS tmp_line;
DROP TABLE IF EXISTS tmp_order;

-- Refresh planner statistics after the bulk load
ANALYZE;


/* =====================================================================
   Quick sanity check — row counts per table
   ===================================================================== */
SELECT 'dim_date'            AS table_name, COUNT(*) AS rows FROM dim_date
UNION ALL SELECT 'dim_customer',        COUNT(*) FROM dim_customer
UNION ALL SELECT 'dim_product',         COUNT(*) FROM dim_product
UNION ALL SELECT 'dim_store',           COUNT(*) FROM dim_store
UNION ALL SELECT 'dim_payment_method',  COUNT(*) FROM dim_payment_method
UNION ALL SELECT 'dim_shipping_method', COUNT(*) FROM dim_shipping_method
UNION ALL SELECT 'fact_sales',          COUNT(*) FROM fact_sales
ORDER BY table_name;


/* =====================================================================
   Scaling up with Mockaroo (optional)
   ---------------------------------------------------------------------
   For larger datasets (100k+ rows), generate CSV files at
   https://mockaroo.com :

   1. Create a schema in Mockaroo matching each dimension
      (e.g. Full Name, Email Address, City, Country for dim_customer).
   2. Export as CSV and load with PostgreSQL's COPY command:

        \copy dim_customer (customer_id, customer_name, email, city, country, customer_segment, signup_date)
              FROM 'customers.csv' WITH (FORMAT csv, HEADER true);

   3. For fact_sales, either generate a CSV with foreign keys in the
      valid key ranges, or adapt the SQL generator above (increase the
      base orders per day in step 7a).

   SQL Server equivalent: use BULK INSERT or the SSMS Import Wizard.
   ===================================================================== */
