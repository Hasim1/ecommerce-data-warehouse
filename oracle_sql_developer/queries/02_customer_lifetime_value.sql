/* =====================================================================
   Query B — Customer Lifetime Value (CLV) Analysis
   ---------------------------------------------------------------------
   Business question : Who are our most valuable customers, and how
                       much revenue does each customer generate in
                       total?
   Techniques        : CTE, COUNT(DISTINCT), DENSE_RANK() window
                       function, derived metric (average order value).
   Engine            : Oracle 12cR2+ (part of the Oracle SQL Developer
                       port of this project; Oracle difference:
                       PostgreSQL's LIMIT 10 becomes
                       FETCH FIRST 10 ROWS ONLY, valid since 12c)
   ===================================================================== */

WITH customer_value AS (
    SELECT
        c.customer_key,
        c.customer_name,
        c.country,
        c.customer_segment,
        COUNT(DISTINCT f.order_id)  AS total_orders,
        SUM(f.total_amount)         AS lifetime_value,
        SUM(f.profit_amount)        AS lifetime_profit,
        MIN(d.full_date)            AS first_order_date,
        MAX(d.full_date)            AS last_order_date
    FROM fact_sales f
    JOIN dim_customer c ON c.customer_key = f.customer_key
    JOIN dim_date     d ON d.date_key     = f.date_key
    GROUP BY c.customer_key, c.customer_name, c.country, c.customer_segment
)
SELECT
    customer_name,
    country,
    customer_segment,
    total_orders,
    ROUND(lifetime_value, 2)                  AS lifetime_value,
    ROUND(lifetime_value / total_orders, 2)   AS avg_order_value,
    ROUND(lifetime_profit, 2)                 AS lifetime_profit,
    first_order_date,
    last_order_date,
    -- DENSE_RANK: customers with identical value share the same rank
    DENSE_RANK() OVER (ORDER BY lifetime_value DESC) AS customer_rank
FROM customer_value
ORDER BY customer_rank
FETCH FIRST 10 ROWS ONLY;   -- top 10 customers; remove to see all
