/* =====================================================================
   E-commerce Data Warehouse & BI Analytics
   ---------------------------------------------------------------------
   File    : oracle_sql_developer/schema/create_tables_oracle.sql
   Engine  : Oracle Database 12c R2+ (tested on 19c / 21c XE)
   Purpose : Creates the complete Star Schema for the data warehouse:
             1 central fact table (fact_sales) + 6 dimension tables.

   This file is part of the ORACLE SQL DEVELOPER PORT of the project.
   Run it in SQL Developer with "Run Script" (F5). It is a straight
   dialect translation of schema/create_tables.sql (PostgreSQL) —
   same tables, same columns, same constraints, same semantics.

   Design notes
   ------------
   * Every dimension has a SURROGATE KEY (integer identity) as its
     primary key, plus the original BUSINESS KEY (customer_id, sku, ...)
     from the source system. This is standard Kimball-style DW practice.
   * dim_date uses a "smart key" in YYYYMMDD format (e.g. 20250115),
     which is the common convention for date dimensions.
   * fact_sales stores one row per ORDER LINE (the "grain" of the fact).
   * unit_cost is copied into the fact table at load time so that profit
     is calculated with the cost that was valid WHEN the sale happened,
     even if the product cost changes later.

   Oracle dialect notes (vs the PostgreSQL original)
   -------------------------------------------------
   * Oracle folds unquoted identifiers to UPPER case (PostgreSQL folds
     to lower case). We keep the identifiers unquoted and identical, so
     fact_sales / FACT_SALES refer to the same table — nothing changes
     for your queries.
   * VARCHAR(n)   -> VARCHAR2(n CHAR)  (n counts characters, not bytes)
   * INT/BIGINT/SMALLINT/NUMERIC(p,s) -> NUMBER with matching precision
   * BOOLEAN      -> NUMBER(1) with a CHECK (value IN (0,1)); Oracle has
     no BOOLEAN column type in plain SQL, so 0 = false and 1 = true.
   * GENERATED ALWAYS AS IDENTITY is supported natively since 12c.
   * "DROP TABLE IF EXISTS" does not exist in Oracle; a small PL/SQL
     block below drops only the tables that are actually present.
   * In Oracle column definitions DEFAULT must come BEFORE NOT NULL.
   ===================================================================== */

/* ---------------------------------------------------------------------
   Drop in dependency order so the script is re-runnable.
   Oracle has no DROP TABLE IF EXISTS, so we loop over user_tables and
   drop only what exists. CASCADE CONSTRAINTS removes dependent foreign
   keys, PURGE skips the recycle bin. Silent when nothing exists.
   --------------------------------------------------------------------- */
BEGIN
    FOR t IN (
        SELECT table_name
        FROM   user_tables
        WHERE  table_name IN ('FACT_SALES',
                              'DIM_DATE',
                              'DIM_CUSTOMER',
                              'DIM_PRODUCT',
                              'DIM_STORE',
                              'DIM_PAYMENT_METHOD',
                              'DIM_SHIPPING_METHOD')
        ORDER  BY CASE table_name WHEN 'FACT_SALES' THEN 0 ELSE 1 END  -- fact first (holds the FKs)
    ) LOOP
        EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS PURGE';
    END LOOP;
END;
/


/* =====================================================================
   DIMENSION: dim_date
   One row per calendar day. Pre-computed attributes (year, quarter,
   month name, weekend flag...) let analysts group by any time period
   without date functions in every query.
   ===================================================================== */
CREATE TABLE dim_date (
    date_key      NUMBER(8)          PRIMARY KEY,        -- smart key: YYYYMMDD (e.g. 20250115), NOT an identity
    full_date     DATE               NOT NULL UNIQUE,
    year          NUMBER(10)         NOT NULL,
    quarter       NUMBER(10)         NOT NULL CHECK (quarter BETWEEN 1 AND 4),
    month         NUMBER(10)         NOT NULL CHECK (month BETWEEN 1 AND 12),
    month_name    VARCHAR2(10 CHAR)  NOT NULL,           -- 'January', 'February', ...
    day_of_month  NUMBER(10)         NOT NULL CHECK (day_of_month BETWEEN 1 AND 31),
    day_of_week   NUMBER(10)         NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),  -- ISO: 1 = Monday, 7 = Sunday
    day_name      VARCHAR2(10 CHAR)  NOT NULL,           -- 'Monday', 'Tuesday', ...
    week_of_year  NUMBER(10)         NOT NULL CHECK (week_of_year BETWEEN 1 AND 53),
    is_weekend    NUMBER(1)          DEFAULT 0 NOT NULL CHECK (is_weekend IN (0, 1))  -- 0 = false, 1 = true
);

COMMENT ON TABLE dim_date IS 'Date dimension: one row per calendar day, pre-computed time attributes for fast grouping.';


/* =====================================================================
   DIMENSION: dim_customer
   Who bought. customer_id is the business key from the operational
   (OLTP) system; customer_key is the warehouse surrogate key.
   ===================================================================== */
CREATE TABLE dim_customer (
    customer_key     NUMBER(10) GENERATED ALWAYS AS IDENTITY PRIMARY KEY,   -- surrogate key
    customer_id      VARCHAR2(20 CHAR)   NOT NULL UNIQUE,                   -- business key from source system
    customer_name    VARCHAR2(100 CHAR)  NOT NULL,
    email            VARCHAR2(150 CHAR)  NOT NULL,
    city             VARCHAR2(60 CHAR),
    country          VARCHAR2(60 CHAR)   NOT NULL,
    customer_segment VARCHAR2(20 CHAR)   DEFAULT 'Consumer' NOT NULL
                     CHECK (customer_segment IN ('Consumer', 'Corporate', 'Small Business')),
    signup_date      DATE
);

COMMENT ON TABLE dim_customer IS 'Customer dimension: descriptive attributes used to slice sales by customer, segment and geography.';


/* =====================================================================
   DIMENSION: dim_product
   What was sold. Category / subcategory / brand support the product
   and category performance analyses.
   ===================================================================== */
CREATE TABLE dim_product (
    product_key   NUMBER(10) GENERATED ALWAYS AS IDENTITY PRIMARY KEY,      -- surrogate key
    sku           VARCHAR2(20 CHAR)   NOT NULL UNIQUE,                      -- business key (stock keeping unit)
    product_name  VARCHAR2(120 CHAR)  NOT NULL,
    category      VARCHAR2(50 CHAR)   NOT NULL,
    subcategory   VARCHAR2(50 CHAR),
    brand         VARCHAR2(50 CHAR),
    unit_cost     NUMBER(10,2)        NOT NULL CHECK (unit_cost >= 0),      -- current purchase/production cost
    list_price    NUMBER(10,2)        NOT NULL CHECK (list_price >= 0)      -- current catalogue price
);

COMMENT ON TABLE dim_product IS 'Product dimension: catalogue attributes for product, brand and category analysis.';


/* =====================================================================
   DIMENSION: dim_store
   Where the sale happened (online store or a physical location).
   ===================================================================== */
CREATE TABLE dim_store (
    store_key   NUMBER(10) GENERATED ALWAYS AS IDENTITY PRIMARY KEY,        -- surrogate key
    store_id    VARCHAR2(20 CHAR)  NOT NULL UNIQUE,                         -- business key
    store_name  VARCHAR2(80 CHAR)  NOT NULL,
    channel     VARCHAR2(20 CHAR)  NOT NULL CHECK (channel IN ('Online', 'Retail')),
    city        VARCHAR2(60 CHAR),
    country     VARCHAR2(60 CHAR)  NOT NULL
);

COMMENT ON TABLE dim_store IS 'Store/channel dimension: separates online sales from physical retail locations.';


/* =====================================================================
   DIMENSION: dim_payment_method
   How the customer paid.
   ===================================================================== */
CREATE TABLE dim_payment_method (
    payment_method_key  NUMBER(10) GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    payment_method_name VARCHAR2(40 CHAR) NOT NULL UNIQUE                   -- 'Credit Card', 'PayPal', ...
);

COMMENT ON TABLE dim_payment_method IS 'Payment method dimension.';


/* =====================================================================
   DIMENSION: dim_shipping_method
   How the order was delivered.
   ===================================================================== */
CREATE TABLE dim_shipping_method (
    shipping_method_key  NUMBER(10) GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    shipping_method_name VARCHAR2(40 CHAR)  NOT NULL UNIQUE,                -- 'Standard', 'Express', ...
    avg_delivery_days    NUMBER(10)         NOT NULL CHECK (avg_delivery_days >= 0),
    base_fee             NUMBER(8,2)        DEFAULT 0 NOT NULL CHECK (base_fee >= 0)
);

COMMENT ON TABLE dim_shipping_method IS 'Shipping method dimension.';


/* =====================================================================
   FACT TABLE: fact_sales   (the centre of the star)
   ---------------------------------------------------------------------
   GRAIN: one row per order line (one product within one order).
   Contains only foreign keys to the dimensions + numeric measures.

   Measures:
     gross_amount  = quantity * unit_price          (before discount)
     total_amount  = gross_amount - discount_amount (net revenue)
     profit_amount = total_amount - quantity * unit_cost
   ===================================================================== */
CREATE TABLE fact_sales (
    sales_key            NUMBER(12) GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    -- Degenerate dimension: the order number lives in the fact table
    -- because it has no descriptive attributes of its own.
    order_id             VARCHAR2(20 CHAR)  NOT NULL,
    order_line           NUMBER(3)          NOT NULL CHECK (order_line >= 1),

    -- Foreign keys to the dimension tables
    date_key             NUMBER(8)          NOT NULL REFERENCES dim_date (date_key),
    customer_key         NUMBER(10)         NOT NULL REFERENCES dim_customer (customer_key),
    product_key          NUMBER(10)         NOT NULL REFERENCES dim_product (product_key),
    store_key            NUMBER(10)         NOT NULL REFERENCES dim_store (store_key),
    payment_method_key   NUMBER(10)         NOT NULL REFERENCES dim_payment_method (payment_method_key),
    shipping_method_key  NUMBER(10)         NOT NULL REFERENCES dim_shipping_method (shipping_method_key),

    -- Measures
    quantity             NUMBER(10)         NOT NULL CHECK (quantity > 0),
    unit_price           NUMBER(10,2)       NOT NULL CHECK (unit_price >= 0),   -- price at time of sale
    unit_cost            NUMBER(10,2)       NOT NULL CHECK (unit_cost >= 0),    -- cost at time of sale
    discount_amount      NUMBER(10,2)       DEFAULT 0 NOT NULL CHECK (discount_amount >= 0),
    gross_amount         NUMBER(12,2)       NOT NULL,                           -- quantity * unit_price
    total_amount         NUMBER(12,2)       NOT NULL,                           -- gross_amount - discount_amount
    profit_amount        NUMBER(12,2)       NOT NULL,                           -- total_amount - quantity * unit_cost

    -- The same order cannot contain the same line number twice
    CONSTRAINT uq_fact_sales_order_line UNIQUE (order_id, order_line),

    -- Data-quality guards: measures must be internally consistent
    CONSTRAINT ck_fact_sales_discount CHECK (discount_amount <= gross_amount),
    CONSTRAINT ck_fact_sales_total    CHECK (total_amount = gross_amount - discount_amount)
);

COMMENT ON TABLE fact_sales IS 'Central fact table. Grain: one row per order line. Measures: quantity, revenue, discount, profit.';

-- Indexes on the foreign keys: these are the join columns used by
-- every analytical query, so indexing them keeps queries fast as
-- the fact table grows.
CREATE INDEX idx_fact_sales_date     ON fact_sales (date_key);
CREATE INDEX idx_fact_sales_customer ON fact_sales (customer_key);
CREATE INDEX idx_fact_sales_product  ON fact_sales (product_key);
CREATE INDEX idx_fact_sales_store    ON fact_sales (store_key);
CREATE INDEX idx_fact_sales_payment  ON fact_sales (payment_method_key);
CREATE INDEX idx_fact_sales_shipping ON fact_sales (shipping_method_key);
