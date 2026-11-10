/* =====================================================================
   E-commerce Data Warehouse & BI Analytics
   ---------------------------------------------------------------------
   File    : schema/create_tables.sql
   Engine  : PostgreSQL 13+
   Purpose : Creates the complete Star Schema for the data warehouse:
             1 central fact table (fact_sales) + 6 dimension tables.

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

   PostgreSQL identifiers are case-insensitive (folded to lower case),
   so Fact_Sales / fact_sales refer to the same table. Snake_case is
   used throughout, which is the PostgreSQL convention.

   A SQL Server version of this script is provided in
   schema/create_tables_sqlserver.sql
   ===================================================================== */

-- Drop in dependency order so the script is re-runnable
DROP TABLE IF EXISTS fact_sales;
DROP TABLE IF EXISTS dim_date;
DROP TABLE IF EXISTS dim_customer;
DROP TABLE IF EXISTS dim_product;
DROP TABLE IF EXISTS dim_store;
DROP TABLE IF EXISTS dim_payment_method;
DROP TABLE IF EXISTS dim_shipping_method;


/* =====================================================================
   DIMENSION: dim_date
   One row per calendar day. Pre-computed attributes (year, quarter,
   month name, weekend flag...) let analysts group by any time period
   without date functions in every query.
   ===================================================================== */
CREATE TABLE dim_date (
    date_key      INT          PRIMARY KEY,        -- smart key: YYYYMMDD (e.g. 20250115)
    full_date     DATE         NOT NULL UNIQUE,
    year          INT          NOT NULL,
    quarter       INT          NOT NULL CHECK (quarter BETWEEN 1 AND 4),
    month         INT          NOT NULL CHECK (month BETWEEN 1 AND 12),
    month_name    VARCHAR(10)  NOT NULL,           -- 'January', 'February', ...
    day_of_month  INT          NOT NULL CHECK (day_of_month BETWEEN 1 AND 31),
    day_of_week   INT          NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),  -- ISO: 1 = Monday, 7 = Sunday
    day_name      VARCHAR(10)  NOT NULL,           -- 'Monday', 'Tuesday', ...
    week_of_year  INT          NOT NULL CHECK (week_of_year BETWEEN 1 AND 53),
    is_weekend    BOOLEAN      NOT NULL DEFAULT FALSE
);

COMMENT ON TABLE dim_date IS 'Date dimension: one row per calendar day, pre-computed time attributes for fast grouping.';


/* =====================================================================
   DIMENSION: dim_customer
   Who bought. customer_id is the business key from the operational
   (OLTP) system; customer_key is the warehouse surrogate key.
   ===================================================================== */
CREATE TABLE dim_customer (
    customer_key     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,   -- surrogate key
    customer_id      VARCHAR(20)   NOT NULL UNIQUE,                  -- business key from source system
    customer_name    VARCHAR(100)  NOT NULL,
    email            VARCHAR(150)  NOT NULL,
    city             VARCHAR(60),
    country          VARCHAR(60)   NOT NULL,
    customer_segment VARCHAR(20)   NOT NULL DEFAULT 'Consumer'
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
    product_key   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,      -- surrogate key
    sku           VARCHAR(20)    NOT NULL UNIQUE,                    -- business key (stock keeping unit)
    product_name  VARCHAR(120)   NOT NULL,
    category      VARCHAR(50)    NOT NULL,
    subcategory   VARCHAR(50),
    brand         VARCHAR(50),
    unit_cost     NUMERIC(10,2)  NOT NULL CHECK (unit_cost >= 0),    -- current purchase/production cost
    list_price    NUMERIC(10,2)  NOT NULL CHECK (list_price >= 0)    -- current catalogue price
);

COMMENT ON TABLE dim_product IS 'Product dimension: catalogue attributes for product, brand and category analysis.';


/* =====================================================================
   DIMENSION: dim_store
   Where the sale happened (online store or a physical location).
   ===================================================================== */
CREATE TABLE dim_store (
    store_key   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,        -- surrogate key
    store_id    VARCHAR(20)  NOT NULL UNIQUE,                        -- business key
    store_name  VARCHAR(80)  NOT NULL,
    channel     VARCHAR(20)  NOT NULL CHECK (channel IN ('Online', 'Retail')),
    city        VARCHAR(60),
    country     VARCHAR(60)  NOT NULL
);

COMMENT ON TABLE dim_store IS 'Store/channel dimension: separates online sales from physical retail locations.';


/* =====================================================================
   DIMENSION: dim_payment_method
   How the customer paid.
   ===================================================================== */
CREATE TABLE dim_payment_method (
    payment_method_key  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    payment_method_name VARCHAR(40) NOT NULL UNIQUE                  -- 'Credit Card', 'PayPal', ...
);

COMMENT ON TABLE dim_payment_method IS 'Payment method dimension.';


/* =====================================================================
   DIMENSION: dim_shipping_method
   How the order was delivered.
   ===================================================================== */
CREATE TABLE dim_shipping_method (
    shipping_method_key  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    shipping_method_name VARCHAR(40)   NOT NULL UNIQUE,              -- 'Standard', 'Express', ...
    avg_delivery_days    INT           NOT NULL CHECK (avg_delivery_days >= 0),
    base_fee             NUMERIC(8,2)  NOT NULL DEFAULT 0 CHECK (base_fee >= 0)
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
    sales_key            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    -- Degenerate dimension: the order number lives in the fact table
    -- because it has no descriptive attributes of its own.
    order_id             VARCHAR(20)   NOT NULL,
    order_line           SMALLINT      NOT NULL CHECK (order_line >= 1),

    -- Foreign keys to the dimension tables
    date_key             INT           NOT NULL REFERENCES dim_date (date_key),
    customer_key         INT           NOT NULL REFERENCES dim_customer (customer_key),
    product_key          INT           NOT NULL REFERENCES dim_product (product_key),
    store_key            INT           NOT NULL REFERENCES dim_store (store_key),
    payment_method_key   INT           NOT NULL REFERENCES dim_payment_method (payment_method_key),
    shipping_method_key  INT           NOT NULL REFERENCES dim_shipping_method (shipping_method_key),

    -- Measures
    quantity             INT           NOT NULL CHECK (quantity > 0),
    unit_price           NUMERIC(10,2) NOT NULL CHECK (unit_price >= 0),   -- price at time of sale
    unit_cost            NUMERIC(10,2) NOT NULL CHECK (unit_cost >= 0),    -- cost at time of sale
    discount_amount      NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
    gross_amount         NUMERIC(12,2) NOT NULL,                           -- quantity * unit_price
    total_amount         NUMERIC(12,2) NOT NULL,                           -- gross_amount - discount_amount
    profit_amount        NUMERIC(12,2) NOT NULL,                           -- total_amount - quantity * unit_cost

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
