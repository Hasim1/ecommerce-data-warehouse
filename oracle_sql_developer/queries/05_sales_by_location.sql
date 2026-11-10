/* =====================================================================
   Query E — Sales by Country and City
   ---------------------------------------------------------------------
   Business question : Which markets generate the most revenue, and
                       where should we focus marketing/expansion?
   Techniques        : JOIN to customer dimension, window aggregate for
                       revenue share, GROUPING SETS for a drill-down
                       report with subtotals.
   Engine            : Oracle 12cR2+ (part of the Oracle SQL Developer
                       port of this project; Oracle fully supports
                       GROUPING SETS, GROUPING() and NULLS FIRST, so
                       query E2 runs unchanged)
   ===================================================================== */

-- ---------------------------------------------------------------------
-- E1. Revenue by country (main report)
-- ---------------------------------------------------------------------
SELECT
    c.country,
    COUNT(DISTINCT f.customer_key)                   AS active_customers,
    COUNT(DISTINCT f.order_id)                       AS total_orders,
    SUM(f.quantity)                                  AS units_sold,
    ROUND(SUM(f.total_amount), 2)                    AS net_revenue,
    ROUND(SUM(f.total_amount)
          / COUNT(DISTINCT f.order_id), 2)           AS avg_order_value,
    ROUND(SUM(f.total_amount) * 100.0
          / SUM(SUM(f.total_amount)) OVER (), 2)     AS revenue_share_pct
FROM fact_sales f
JOIN dim_customer c ON c.customer_key = f.customer_key
GROUP BY c.country
ORDER BY net_revenue DESC;


-- ---------------------------------------------------------------------
-- E2. Drill-down: country → city, with subtotals and a grand total
--     GROUPING SETS produces three levels in one pass:
--       (country, city)  = detail rows
--       (country)        = subtotal per country
--       ()               = grand total
-- ---------------------------------------------------------------------
SELECT
    COALESCE(c.country, 'ALL COUNTRIES')  AS country,
    -- GROUPING() = 1 when the column was rolled up in this row, which
    -- lets us label subtotal and grand-total rows correctly
    CASE
        WHEN GROUPING(c.country) = 1 THEN '(grand total)'
        WHEN GROUPING(c.city)    = 1 THEN '(country total)'
        ELSE c.city
    END                                   AS city,
    COUNT(DISTINCT f.order_id)            AS total_orders,
    ROUND(SUM(f.total_amount), 2)         AS net_revenue
FROM fact_sales f
JOIN dim_customer c ON c.customer_key = f.customer_key
GROUP BY GROUPING SETS ((c.country, c.city), (c.country), ())
ORDER BY
    GROUPING(c.country) DESC,   -- grand total first
    c.country NULLS FIRST,
    GROUPING(c.city) DESC,      -- country subtotal before its cities
    net_revenue DESC;
