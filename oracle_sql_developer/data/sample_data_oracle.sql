/* =====================================================================
   E-commerce Data Warehouse & BI Analytics  —  Oracle SQL Developer port
   ---------------------------------------------------------------------
   File    : oracle_sql_developer/data/sample_data_oracle.sql
   Engine  : Oracle Database 12c R2+  (tested on 19c / 21c XE)
   Purpose : Loads realistic mock data into the star schema.

   Run oracle_sql_developer/schema/create_tables_oracle.sql FIRST.
   This script assumes freshly created (empty) tables.
   Run it in SQL Developer with "Run Script" (F5).

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

   The generator seeds DBMS_RANDOM, so the data is REPRODUCIBLE:
   everyone who runs this script on Oracle gets the same numbers.
   (The numbers differ from the PostgreSQL dataset because the random
   number generator differs, but the statistical patterns are identical.)
   ===================================================================== */


/* =====================================================================
   1. dim_date — generate two full years of calendar days (730 rows)
   ---------------------------------------------------------------------
   Oracle's classic row generator: CONNECT BY LEVEL against dual.
   Month/day names are forced to English so the data does not depend
   on the session's NLS language settings.
   ===================================================================== */
INSERT INTO dim_date
      (date_key, full_date, year, quarter, month, month_name,
       day_of_month, day_of_week, day_name, week_of_year, is_weekend)
SELECT
    TO_NUMBER(TO_CHAR(d, 'YYYYMMDD')),                          -- smart key, e.g. 20250115
    d,
    EXTRACT(YEAR  FROM d),
    TO_NUMBER(TO_CHAR(d, 'Q')),
    EXTRACT(MONTH FROM d),
    TRIM(TO_CHAR(d, 'Month', 'NLS_DATE_LANGUAGE=ENGLISH')),     -- 'January', 'February', ...
    EXTRACT(DAY   FROM d),
    TRUNC(d) - TRUNC(d, 'IW') + 1,                              -- ISO day of week: 1 = Monday ... 7 = Sunday
    TRIM(TO_CHAR(d, 'Day', 'NLS_DATE_LANGUAGE=ENGLISH')),       -- 'Monday', 'Tuesday', ...
    TO_NUMBER(TO_CHAR(d, 'IW')),                                -- ISO week of year
    CASE WHEN TRUNC(d) - TRUNC(d, 'IW') + 1 IN (6, 7)           -- weekend flag (1/0, no BOOLEAN in Oracle SQL)
         THEN 1 ELSE 0 END
FROM (
    SELECT DATE '2025-01-01' + LEVEL - 1 AS d
    FROM dual
    CONNECT BY LEVEL <= 730                                     -- 365 (2025) + 365 (2026)
);


/* =====================================================================
   2. dim_customer — 20 customers (surrogate keys auto-assigned)
   ---------------------------------------------------------------------
   Oracle does not support multi-row INSERT ... VALUES (...),(...),
   so each row gets its own INSERT statement.
   ===================================================================== */
INSERT INTO dim_customer (customer_id, customer_name, email, city, country, customer_segment, signup_date)
VALUES ('CUST-0001', 'Emma Müller',      'emma.mueller@example.com',    'Berlin',    'Germany',        'Consumer',       DATE '2023-03-12');
INSERT INTO dim_customer (customer_id, customer_name, email, city, country, customer_segment, signup_date)
VALUES ('CUST-0002', 'James Carter',     'james.carter@example.com',    'London',    'United Kingdom', 'Consumer',       DATE '2022-11-05');
INSERT INTO dim_customer (customer_id, customer_name, email, city, country, customer_segment, signup_date)
VALUES ('CUST-0003', 'Sophia Rossi',     'sophia.rossi@example.com',    'Milan',     'Italy',          'Consumer',       DATE '2024-01-20');
INSERT INTO dim_customer (customer_id, customer_name, email, city, country, customer_segment, signup_date)
VALUES ('CUST-0004', 'Ali Hassan',       'ali.hassan@example.com',      'Dubai',     'UAE',            'Corporate',      DATE '2023-06-30');
INSERT INTO dim_customer (customer_id, customer_name, email, city, country, customer_segment, signup_date)
VALUES ('CUST-0005', 'Fatima Khan',      'fatima.khan@example.com',     'Karachi',   'Pakistan',       'Consumer',       DATE '2024-04-18');
INSERT INTO dim_customer (customer_id, customer_name, email, city, country, customer_segment, signup_date)
VALUES ('CUST-0006', 'John Smith',       'john.smith@example.com',      'New York',  'USA',            'Small Business', DATE '2022-08-14');
INSERT INTO dim_customer (customer_id, customer_name, email, city, country, customer_segment, signup_date)
VALUES ('CUST-0007', 'Olivia Brown',     'olivia.brown@example.com',    'Toronto',   'Canada',         'Consumer',       DATE '2023-09-02');
INSERT INTO dim_customer (customer_id, customer_name, email, city, country, customer_segment, signup_date)
VALUES ('CUST-0008', 'Ahmed Mahmoud',    'ahmed.mahmoud@example.com',   'Cairo',     'Egypt',          'Consumer',       DATE '2024-02-25');
INSERT INTO dim_customer (customer_id, customer_name, email, city, country, customer_segment, signup_date)
VALUES ('CUST-0009', 'Chloé Dubois',     'chloe.dubois@example.com',    'Paris',     'France',         'Consumer',       DATE '2023-12-01');
INSERT INTO dim_customer (customer_id, customer_name, email, city, country, customer_segment, signup_date)
VALUES ('CUST-0010', 'Lucas Silva',      'lucas.silva@example.com',     'São Paulo', 'Brazil',         'Consumer',       DATE '2024-05-09');
INSERT INTO dim_customer (customer_id, customer_name, email, city, country, customer_segment, signup_date)
VALUES ('CUST-0011', 'Sara Al-Farsi',    'sara.alfarsi@example.com',    'Riyadh',    'Saudi Arabia',   'Corporate',      DATE '2023-01-17');
INSERT INTO dim_customer (customer_id, customer_name, email, city, country, customer_segment, signup_date)
VALUES ('CUST-0012', 'David Miller',     'david.miller@example.com',    'Chicago',   'USA',            'Consumer',       DATE '2022-10-22');
INSERT INTO dim_customer (customer_id, customer_name, email, city, country, customer_segment, signup_date)
VALUES ('CUST-0013', 'Anna Kowalska',    'anna.kowalska@example.com',   'Warsaw',    'Poland',         'Consumer',       DATE '2024-03-08');
INSERT INTO dim_customer (customer_id, customer_name, email, city, country, customer_segment, signup_date)
VALUES ('CUST-0014', 'Mehmet Yılmaz',    'mehmet.yilmaz@example.com',   'Istanbul',  'Turkey',         'Small Business', DATE '2023-07-19');
INSERT INTO dim_customer (customer_id, customer_name, email, city, country, customer_segment, signup_date)
VALUES ('CUST-0015', 'Grace Wilson',     'grace.wilson@example.com',    'Sydney',    'Australia',      'Consumer',       DATE '2024-06-11');
INSERT INTO dim_customer (customer_id, customer_name, email, city, country, customer_segment, signup_date)
VALUES ('CUST-0016', 'Hiro Tanaka',      'hiro.tanaka@example.com',     'Tokyo',     'Japan',          'Consumer',       DATE '2023-04-27');
INSERT INTO dim_customer (customer_id, customer_name, email, city, country, customer_segment, signup_date)
VALUES ('CUST-0017', 'Layla Ahmed',      'layla.ahmed@example.com',     'Amman',     'Jordan',         'Consumer',       DATE '2024-08-03');
INSERT INTO dim_customer (customer_id, customer_name, email, city, country, customer_segment, signup_date)
VALUES ('CUST-0018', 'Peter Schmidt',    'peter.schmidt@example.com',   'Munich',    'Germany',        'Corporate',      DATE '2022-12-15');
INSERT INTO dim_customer (customer_id, customer_name, email, city, country, customer_segment, signup_date)
VALUES ('CUST-0019', 'Isabella García',  'isabella.garcia@example.com', 'Madrid',    'Spain',          'Consumer',       DATE '2023-10-29');
INSERT INTO dim_customer (customer_id, customer_name, email, city, country, customer_segment, signup_date)
VALUES ('CUST-0020', 'Omar Farouk',      'omar.farouk@example.com',     'Doha',      'Qatar',          'Consumer',       DATE '2024-07-21');


/* =====================================================================
   3. dim_product — 20 products in 5 categories
   ===================================================================== */
INSERT INTO dim_product (sku, product_name, category, subcategory, brand, unit_cost, list_price)
VALUES ('EL-001', 'AeroBook 14 Laptop',            'Electronics',       'Computers',        'Novatech',   620.00, 899.99);
INSERT INTO dim_product (sku, product_name, category, subcategory, brand, unit_cost, list_price)
VALUES ('EL-002', 'Pulse X Smartphone',            'Electronics',       'Phones',           'Novatech',   410.00, 649.99);
INSERT INTO dim_product (sku, product_name, category, subcategory, brand, unit_cost, list_price)
VALUES ('EL-003', 'SoundCore Wireless Earbuds',    'Electronics',       'Audio',            'Audion',      28.00,  59.99);
INSERT INTO dim_product (sku, product_name, category, subcategory, brand, unit_cost, list_price)
VALUES ('EL-004', 'UltraView 27" Monitor',         'Electronics',       'Monitors',         'ViewMax',    145.00, 249.99);
INSERT INTO dim_product (sku, product_name, category, subcategory, brand, unit_cost, list_price)
VALUES ('EL-005', 'MechType Pro Keyboard',         'Electronics',       'Accessories',      'HyperKeys',   38.00,  89.99);
INSERT INTO dim_product (sku, product_name, category, subcategory, brand, unit_cost, list_price)
VALUES ('EL-006', 'Portable Bluetooth Speaker',    'Electronics',       'Audio',            'Audion',      21.00,  49.99);
INSERT INTO dim_product (sku, product_name, category, subcategory, brand, unit_cost, list_price)
VALUES ('HK-001', 'BrewMaster Coffee Machine',     'Home & Kitchen',    'Coffee & Tea',     'KitchenPro',  85.00, 179.99);
INSERT INTO dim_product (sku, product_name, category, subcategory, brand, unit_cost, list_price)
VALUES ('HK-002', 'TurboBlend 900 Blender',        'Home & Kitchen',    'Small Appliances', 'KitchenPro',  32.00,  74.99);
INSERT INTO dim_product (sku, product_name, category, subcategory, brand, unit_cost, list_price)
VALUES ('HK-003', '10-Piece Cookware Set',         'Home & Kitchen',    'Cookware',         'HomeChef',    70.00, 149.99);
INSERT INTO dim_product (sku, product_name, category, subcategory, brand, unit_cost, list_price)
VALUES ('HK-004', 'RoboClean R7 Vacuum',           'Home & Kitchen',    'Cleaning',         'CleanTech',  190.00, 329.99);
INSERT INTO dim_product (sku, product_name, category, subcategory, brand, unit_cost, list_price)
VALUES ('FA-001', 'Urban Runner Sneakers',         'Fashion',           'Shoes',            'Stride',      24.00,  79.99);
INSERT INTO dim_product (sku, product_name, category, subcategory, brand, unit_cost, list_price)
VALUES ('FA-002', 'Classic Denim Jacket',          'Fashion',           'Outerwear',        'NorthLoom',   22.00,  64.99);
INSERT INTO dim_product (sku, product_name, category, subcategory, brand, unit_cost, list_price)
VALUES ('FA-003', 'Slim Fit Jeans',                'Fashion',           'Clothing',         'NorthLoom',   14.00,  44.99);
INSERT INTO dim_product (sku, product_name, category, subcategory, brand, unit_cost, list_price)
VALUES ('FA-004', 'Minimalist Steel Watch',        'Fashion',           'Accessories',      'Tempus',      55.00, 129.99);
INSERT INTO dim_product (sku, product_name, category, subcategory, brand, unit_cost, list_price)
VALUES ('SP-001', 'EcoFlex Yoga Mat',              'Sports & Outdoors', 'Fitness',          'FitLife',      9.00,  29.99);
INSERT INTO dim_product (sku, product_name, category, subcategory, brand, unit_cost, list_price)
VALUES ('SP-002', 'Adjustable Dumbbell Set 20kg',  'Sports & Outdoors', 'Fitness',          'IronCore',    48.00, 119.99);
INSERT INTO dim_product (sku, product_name, category, subcategory, brand, unit_cost, list_price)
VALUES ('SP-003', 'Trail 2-Person Tent',           'Sports & Outdoors', 'Camping',          'CampRight',   62.00, 139.99);
INSERT INTO dim_product (sku, product_name, category, subcategory, brand, unit_cost, list_price)
VALUES ('BH-001', 'HydraGlow Skincare Set',        'Beauty & Health',   'Skincare',         'Lumière',     18.00,  49.99);
INSERT INTO dim_product (sku, product_name, category, subcategory, brand, unit_cost, list_price)
VALUES ('BH-002', 'IonPro Hair Dryer',             'Beauty & Health',   'Hair Care',        'GlamTech',    26.00,  69.99);
INSERT INTO dim_product (sku, product_name, category, subcategory, brand, unit_cost, list_price)
VALUES ('BH-003', 'Electric Toothbrush S2',        'Beauty & Health',   'Oral Care',        'DentaFresh',  20.00,  54.99);


/* =====================================================================
   4. dim_store — one online channel + three retail locations
   (the online store has no physical city, hence NULL)
   ===================================================================== */
INSERT INTO dim_store (store_id, store_name, channel, city, country)
VALUES ('ST-001', 'Online Store',        'Online', NULL,     'Global');
INSERT INTO dim_store (store_id, store_name, channel, city, country)
VALUES ('ST-002', 'Berlin Flagship',     'Retail', 'Berlin', 'Germany');
INSERT INTO dim_store (store_id, store_name, channel, city, country)
VALUES ('ST-003', 'Dubai Mall Outlet',   'Retail', 'Dubai',  'UAE');
INSERT INTO dim_store (store_id, store_name, channel, city, country)
VALUES ('ST-004', 'London Oxford St.',   'Retail', 'London', 'United Kingdom');


/* =====================================================================
   5. dim_payment_method
   ===================================================================== */
INSERT INTO dim_payment_method (payment_method_name) VALUES ('Credit Card');
INSERT INTO dim_payment_method (payment_method_name) VALUES ('Debit Card');
INSERT INTO dim_payment_method (payment_method_name) VALUES ('PayPal');
INSERT INTO dim_payment_method (payment_method_name) VALUES ('Cash on Delivery');
INSERT INTO dim_payment_method (payment_method_name) VALUES ('Bank Transfer');


/* =====================================================================
   6. dim_shipping_method
   ===================================================================== */
INSERT INTO dim_shipping_method (shipping_method_name, avg_delivery_days, base_fee)
VALUES ('Standard',        5, 4.99);
INSERT INTO dim_shipping_method (shipping_method_name, avg_delivery_days, base_fee)
VALUES ('Express',         2, 9.99);
INSERT INTO dim_shipping_method (shipping_method_name, avg_delivery_days, base_fee)
VALUES ('Same-Day',        0, 14.99);
INSERT INTO dim_shipping_method (shipping_method_name, avg_delivery_days, base_fee)
VALUES ('In-Store Pickup', 0, 0.00);

COMMIT;


/* =====================================================================
   7. fact_sales — generate ~5,000 realistic order lines for 2025
   ---------------------------------------------------------------------
   The PostgreSQL original builds a temporary table of orders and then
   explodes it into order lines with set-based SQL. In Oracle the same
   business rules are easier to read (and just as fast at this volume)
   as a single PL/SQL anonymous block:

     - loop over each of the 365 days of 2025
     - decide how many ORDERS happen that day
         (base volume + seasonality + weekend uplift + noise)
     - for each order pick customer / store / payment / shipping
         (customers are SKEWED so a few become "heavy buyers")
     - explode each order into 1-3 ORDER LINES, each picking a product
         (products are SKEWED so a few become clear bestsellers)
     - ~35% of lines get a 5%-25% discount
     - all measures are calculated exactly like the fact table defines:
         gross  = quantity * unit_price
         total  = gross - discount
         profit = total - quantity * unit_cost

   The dimension keys are loaded into arrays up-front (BULK COLLECT),
   so the generator never assumes identity values start at 1.
   ===================================================================== */
DECLARE
    TYPE t_num_tab IS TABLE OF NUMBER;

    -- Dimension key arrays (parallel arrays for product cost/price)
    customer_keys    t_num_tab;
    store_keys       t_num_tab;
    payment_keys     t_num_tab;
    shipping_keys    t_num_tab;
    product_keys     t_num_tab;
    product_costs    t_num_tab;
    product_prices   t_num_tab;

    -- Order-level variables
    v_order_date     DATE;
    v_month          PLS_INTEGER;
    v_iso_dow        PLS_INTEGER;          -- ISO day of week: 1 = Monday ... 7 = Sunday
    v_orders_today   PLS_INTEGER;
    v_order_seq      PLS_INTEGER := 0;     -- running order number across the whole year
    v_order_id       VARCHAR2(20);
    v_lines_in_order PLS_INTEGER;

    -- Index picks into the key arrays
    v_cust_idx       PLS_INTEGER;
    v_store_idx      PLS_INTEGER;
    v_pay_idx        PLS_INTEGER;
    v_ship_idx       PLS_INTEGER;
    v_prod_idx       PLS_INTEGER;

    -- Line-level measures
    v_quantity       PLS_INTEGER;
    v_gross          NUMBER(12,2);
    v_discount       NUMBER(10,2);
    v_total          NUMBER(12,2);
    v_profit         NUMBER(12,2);
BEGIN
    -- Seed the random generator once → reproducible dataset.
    -- (Numbers differ from the PostgreSQL dataset because the RNG
    --  differs, but the statistical patterns are identical.)
    DBMS_RANDOM.SEED(42);

    -- Load the dimension keys ordered by key, so array index i maps
    -- to the i-th smallest surrogate key (works even if identity
    -- values do not start at 1).
    SELECT customer_key        BULK COLLECT INTO customer_keys
      FROM dim_customer        ORDER BY customer_key;
    SELECT store_key           BULK COLLECT INTO store_keys
      FROM dim_store            ORDER BY store_key;
    SELECT payment_method_key  BULK COLLECT INTO payment_keys
      FROM dim_payment_method  ORDER BY payment_method_key;
    SELECT shipping_method_key BULK COLLECT INTO shipping_keys
      FROM dim_shipping_method ORDER BY shipping_method_key;
    SELECT product_key, unit_cost, list_price
      BULK COLLECT INTO product_keys, product_costs, product_prices
      FROM dim_product          ORDER BY product_key;

    -- ---- Loop over every day of 2025 ---------------------------------
    FOR day_offset IN 0 .. 364 LOOP
        v_order_date := DATE '2025-01-01' + day_offset;
        v_month      := EXTRACT(MONTH FROM v_order_date);
        v_iso_dow    := TRUNC(v_order_date) - TRUNC(v_order_date, 'IW') + 1;

        -- Number of orders today: base volume + seasonality
        -- + weekend uplift + day-to-day noise
        v_orders_today := 4                                        -- base orders per day
            + CASE WHEN v_month IN (11, 12) THEN 5                 -- holiday season peak
                   WHEN v_month IN (6, 7)   THEN 2                 -- summer bump
                   ELSE 0 END
            + CASE WHEN v_iso_dow IN (6, 7) THEN 2                 -- weekend uplift
                   ELSE 0 END
            + FLOOR(DBMS_RANDOM.VALUE * 4);                        -- day-to-day noise

        -- ---- Orders of the day ----------------------------------------
        FOR o IN 1 .. v_orders_today LOOP
            v_order_seq := v_order_seq + 1;
            v_order_id  := 'SO-2025-' || LPAD(TO_CHAR(v_order_seq), 5, '0');

            -- POWER() skews the distribution: low indexes are picked
            -- more often, so some customers become "heavy buyers"
            -- (realistic for customer-lifetime-value analysis)
            v_cust_idx  := 1 + FLOOR(POWER(DBMS_RANDOM.VALUE, 1.5) * customer_keys.COUNT);

            -- Store / payment / shipping are picked uniformly
            v_store_idx := 1 + FLOOR(DBMS_RANDOM.VALUE * store_keys.COUNT);
            v_pay_idx   := 1 + FLOOR(DBMS_RANDOM.VALUE * payment_keys.COUNT);
            v_ship_idx  := 1 + FLOOR(DBMS_RANDOM.VALUE * shipping_keys.COUNT);

            -- Each order gets 1-3 lines
            v_lines_in_order := 1 + FLOOR(DBMS_RANDOM.VALUE * 3);

            -- ---- Order lines → fact_sales -----------------------------
            FOR line_no IN 1 .. v_lines_in_order LOOP
                -- POWER(...,2) makes low product indexes (electronics)
                -- more popular → clear bestsellers in the analysis
                v_prod_idx := 1 + FLOOR(POWER(DBMS_RANDOM.VALUE, 2) * product_keys.COUNT);
                v_quantity := 1 + FLOOR(DBMS_RANDOM.VALUE * 3);

                v_gross := v_quantity * product_prices(v_prod_idx);

                -- ~35% of order lines get a discount between 5% and 25%
                IF DBMS_RANDOM.VALUE < 0.35 THEN
                    v_discount := ROUND(v_gross * (0.05 + DBMS_RANDOM.VALUE * 0.20), 2);
                ELSE
                    v_discount := 0;
                END IF;

                v_total  := v_gross - v_discount;
                v_profit := v_total - v_quantity * product_costs(v_prod_idx);

                INSERT INTO fact_sales
                      (order_id, order_line, date_key, customer_key, product_key, store_key,
                       payment_method_key, shipping_method_key,
                       quantity, unit_price, unit_cost,
                       discount_amount, gross_amount, total_amount, profit_amount)
                VALUES
                      (v_order_id,
                       line_no,
                       TO_NUMBER(TO_CHAR(v_order_date, 'YYYYMMDD')),
                       customer_keys(v_cust_idx),
                       product_keys(v_prod_idx),
                       store_keys(v_store_idx),
                       payment_keys(v_pay_idx),
                       shipping_keys(v_ship_idx),
                       v_quantity,
                       product_prices(v_prod_idx),        -- price at time of sale
                       product_costs(v_prod_idx),         -- cost at time of sale
                       v_discount,
                       v_gross,
                       v_total,
                       v_profit);
            END LOOP;
        END LOOP;
    END LOOP;

    COMMIT;
END;
/


/* =====================================================================
   Refresh optimizer statistics after the bulk load
   (Oracle equivalent of PostgreSQL's ANALYZE)
   ===================================================================== */
BEGIN
    DBMS_STATS.GATHER_SCHEMA_STATS(ownname => USER);
END;
/


/* =====================================================================
   Quick sanity check — row counts per table
   ===================================================================== */
SELECT 'dim_date'            AS table_name, COUNT(*) AS row_count FROM dim_date
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
   2. Export as CSV and load it with one of Oracle's tools:
        - SQL Developer's Import Data wizard: right-click the table in
          the Connections tree → Import Data... → pick the CSV and map
          the columns (easiest option).
        - SQL*Loader (sqlldr) with a simple control file, for large
          files or repeatable command-line loads.
   3. For fact_sales, either generate a CSV with foreign keys in the
      valid key ranges, or adapt the PL/SQL generator above (increase
      the base orders per day).
   ===================================================================== */
