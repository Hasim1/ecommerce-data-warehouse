/* =====================================================================
   Query C — Category Performance Analysis
   ---------------------------------------------------------------------
   Business question : Which product categories drive revenue and
                       profit, and which are underperforming?
   Techniques        : JOIN to product dimension, aggregate measures,
                       window function over an aggregate to compute
                       each category's share of total revenue.
   Engine            : Oracle 12cR2+ (part of the Oracle SQL Developer
                       port of this project; syntax is identical to
                       the PostgreSQL original)
   ===================================================================== */

SELECT
    p.category,
    SUM(f.quantity)                                  AS units_sold,
    ROUND(SUM(f.gross_amount), 2)                    AS gross_revenue,     -- before discounts
    ROUND(SUM(f.discount_amount), 2)                 AS total_discounts,
    ROUND(SUM(f.total_amount), 2)                    AS net_revenue,       -- after discounts
    ROUND(SUM(f.profit_amount), 2)                   AS profit,
    -- profit as a percentage of net revenue
    ROUND(SUM(f.profit_amount)
          / NULLIF(SUM(f.total_amount), 0) * 100, 2) AS profit_margin_pct,
    -- this category's share of company-wide net revenue
    ROUND(SUM(f.total_amount) * 100.0
          / SUM(SUM(f.total_amount)) OVER (), 2)     AS revenue_share_pct
FROM fact_sales f
JOIN dim_product p ON p.product_key = f.product_key
GROUP BY p.category
ORDER BY net_revenue DESC;
