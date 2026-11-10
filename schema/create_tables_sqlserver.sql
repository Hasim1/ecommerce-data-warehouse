/* =====================================================================
   E-commerce Data Warehouse & BI Analytics
   ---------------------------------------------------------------------
   File    : schema/create_tables_sqlserver.sql
   Engine  : Microsoft SQL Server 2019+ (also works on Azure SQL)
   Purpose : Same Star Schema as schema/create_tables.sql, adapted to
             T-SQL syntax.

   Main differences from the PostgreSQL version:
     * IDENTITY(1,1)          instead of GENERATED ALWAYS AS IDENTITY
     * BIT                    instead of BOOLEAN
     * NVARCHAR               instead of VARCHAR (Unicode-safe)
     * DROP TABLE IF EXISTS   works the same on SQL Server 2016+
     * No COMMENT ON syntax   (comments kept as inline -- comments)
   ===================================================================== */

-- Drop in dependency order so the script is re-runnable
DROP TABLE IF EXISTS fact_sales;
DROP TABLE IF EXISTS dim_date;
DROP TABLE IF EXISTS dim_customer;
DROP TABLE IF EXISTS dim_product;
DROP TABLE IF EXISTS dim_store;
DROP TABLE IF EXISTS dim_payment_method;
DROP TABLE IF EXISTS dim_shipping_method;
GO

-- ========================= DIMENSION: dim_date =======================
-- One row per calendar day, smart key in YYYYMMDD format.
CREATE TABLE dim_date (
    date_key      INT           NOT NULL PRIMARY KEY,   -- YYYYMMDD, e.g. 20250115
    full_date     DATE          NOT NULL UNIQUE,
    [year]        INT           NOT NULL,
    [quarter]     INT           NOT NULL CHECK ([quarter] BETWEEN 1 AND 4),
    [month]       INT           NOT NULL CHECK ([month] BETWEEN 1 AND 12),
    month_name    NVARCHAR(10)  NOT NULL,
    day_of_month  INT           NOT NULL CHECK (day_of_month BETWEEN 1 AND 31),
    day_of_week   INT           NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),  -- ISO: 1 = Monday
    day_name      NVARCHAR(10)  NOT NULL,
    week_of_year  INT           NOT NULL CHECK (week_of_year BETWEEN 1 AND 53),
    is_weekend    BIT           NOT NULL DEFAULT 0
);
GO

-- ====================== DIMENSION: dim_customer ======================
CREATE TABLE dim_customer (
    customer_key     INT IDENTITY(1,1) PRIMARY KEY,      -- surrogate key
    customer_id      NVARCHAR(20)   NOT NULL UNIQUE,     -- business key from source system
    customer_name    NVARCHAR(100)  NOT NULL,
    email            NVARCHAR(150)  NOT NULL,
    city             NVARCHAR(60),
    country          NVARCHAR(60)   NOT NULL,
    customer_segment NVARCHAR(20)   NOT NULL DEFAULT 'Consumer'
                     CHECK (customer_segment IN ('Consumer', 'Corporate', 'Small Business')),
    signup_date      DATE
);
GO

-- ======================= DIMENSION: dim_product ======================
CREATE TABLE dim_product (
    product_key   INT IDENTITY(1,1) PRIMARY KEY,         -- surrogate key
    sku           NVARCHAR(20)   NOT NULL UNIQUE,        -- business key
    product_name  NVARCHAR(120)  NOT NULL,
    category      NVARCHAR(50)   NOT NULL,
    subcategory   NVARCHAR(50),
    brand         NVARCHAR(50),
    unit_cost     NUMERIC(10,2)  NOT NULL CHECK (unit_cost >= 0),
    list_price    NUMERIC(10,2)  NOT NULL CHECK (list_price >= 0)
);
GO

-- ======================== DIMENSION: dim_store =======================
CREATE TABLE dim_store (
    store_key   INT IDENTITY(1,1) PRIMARY KEY,
    store_id    NVARCHAR(20)  NOT NULL UNIQUE,
    store_name  NVARCHAR(80)  NOT NULL,
    channel     NVARCHAR(20)  NOT NULL CHECK (channel IN ('Online', 'Retail')),
    city        NVARCHAR(60),
    country     NVARCHAR(60)  NOT NULL
);
GO

-- =================== DIMENSION: dim_payment_method ===================
CREATE TABLE dim_payment_method (
    payment_method_key  INT IDENTITY(1,1) PRIMARY KEY,
    payment_method_name NVARCHAR(40) NOT NULL UNIQUE
);
GO

-- ================== DIMENSION: dim_shipping_method ===================
CREATE TABLE dim_shipping_method (
    shipping_method_key  INT IDENTITY(1,1) PRIMARY KEY,
    shipping_method_name NVARCHAR(40)  NOT NULL UNIQUE,
    avg_delivery_days    INT           NOT NULL CHECK (avg_delivery_days >= 0),
    base_fee             NUMERIC(8,2)  NOT NULL DEFAULT 0 CHECK (base_fee >= 0)
);
GO

-- ==================== FACT TABLE: fact_sales =========================
-- GRAIN: one row per order line (one product within one order).
CREATE TABLE fact_sales (
    sales_key            BIGINT IDENTITY(1,1) PRIMARY KEY,

    -- Degenerate dimension: order number kept directly in the fact
    order_id             NVARCHAR(20)  NOT NULL,
    order_line           SMALLINT      NOT NULL CHECK (order_line >= 1),

    -- Foreign keys to the dimensions
    date_key             INT NOT NULL FOREIGN KEY REFERENCES dim_date (date_key),
    customer_key         INT NOT NULL FOREIGN KEY REFERENCES dim_customer (customer_key),
    product_key          INT NOT NULL FOREIGN KEY REFERENCES dim_product (product_key),
    store_key            INT NOT NULL FOREIGN KEY REFERENCES dim_store (store_key),
    payment_method_key   INT NOT NULL FOREIGN KEY REFERENCES dim_payment_method (payment_method_key),
    shipping_method_key  INT NOT NULL FOREIGN KEY REFERENCES dim_shipping_method (shipping_method_key),

    -- Measures
    quantity             INT           NOT NULL CHECK (quantity > 0),
    unit_price           NUMERIC(10,2) NOT NULL CHECK (unit_price >= 0),
    unit_cost            NUMERIC(10,2) NOT NULL CHECK (unit_cost >= 0),
    discount_amount      NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
    gross_amount         NUMERIC(12,2) NOT NULL,   -- quantity * unit_price
    total_amount         NUMERIC(12,2) NOT NULL,   -- gross_amount - discount_amount
    profit_amount        NUMERIC(12,2) NOT NULL,   -- total_amount - quantity * unit_cost

    CONSTRAINT uq_fact_sales_order_line UNIQUE (order_id, order_line),
    CONSTRAINT ck_fact_sales_discount CHECK (discount_amount <= gross_amount),
    CONSTRAINT ck_fact_sales_total    CHECK (total_amount = gross_amount - discount_amount)
);
GO

-- Indexes on join columns used by every analytical query
CREATE INDEX idx_fact_sales_date     ON fact_sales (date_key);
CREATE INDEX idx_fact_sales_customer ON fact_sales (customer_key);
CREATE INDEX idx_fact_sales_product  ON fact_sales (product_key);
CREATE INDEX idx_fact_sales_store    ON fact_sales (store_key);
CREATE INDEX idx_fact_sales_payment  ON fact_sales (payment_method_key);
CREATE INDEX idx_fact_sales_shipping ON fact_sales (shipping_method_key);
GO
