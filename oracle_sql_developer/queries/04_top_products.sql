/* =====================================================================
   Query D — Top Products by Revenue
   ---------------------------------------------------------------------
   Business question : Which individual products are our bestsellers,
                       and how much does each contribute to total
                       revenue?
   Techniques        : CTE, RANK() window function, revenue share via
                       window aggregate.
   Engine            : Oracle 12cR2+ (part of the Oracle SQL Developer
                       port of this project; Oracle difference:
                       PostgreSQL's LIMIT 10 becomes
                       FETCH FIRST 10 ROWS ONLY, valid since 12c)
   ===================================================================== */

WITH product_sales AS (
    SELECT
        p.product_name,
        p.category,
        p.brand,
        SUM(f.quantity)       AS units_sold,
        SUM(f.total_amount)   AS net_revenue,
        SUM(f.profit_amount)  AS profit
    FROM fact_sales f
    JOIN dim_product p ON p.product_key = f.product_key
    GROUP BY p.product_name, p.category, p.brand
)
SELECT
    RANK() OVER (ORDER BY net_revenue DESC)      AS revenue_rank,
    product_name,
    category,
    brand,
    units_sold,
    ROUND(net_revenue, 2)                        AS net_revenue,
    ROUND(profit, 2)                             AS profit,
    ROUND(net_revenue * 100.0
          / SUM(net_revenue) OVER (), 2)         AS revenue_share_pct
FROM product_sales
ORDER BY revenue_rank
FETCH FIRST 10 ROWS ONLY;   -- top 10 products; remove to see all
