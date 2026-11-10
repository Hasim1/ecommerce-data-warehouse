/* =====================================================================
   Query A — Month-over-Month (MoM) Sales Growth
   ---------------------------------------------------------------------
   Business question : Is revenue growing or shrinking month by month,
                       and by how much?
   Techniques        : CTE, JOIN to date dimension, LAG() window
                       function, NULLIF() to avoid division by zero.
   Engine            : Oracle 12cR2+ (part of the Oracle SQL Developer
                       port of this project; syntax is identical to
                       the PostgreSQL original)
   ===================================================================== */

WITH monthly_revenue AS (
    -- Aggregate net revenue per calendar month using the date dimension
    SELECT
        d.year,
        d.month,
        d.month_name,
        SUM(f.total_amount) AS total_revenue
    FROM fact_sales f
    JOIN dim_date d ON d.date_key = f.date_key
    GROUP BY d.year, d.month, d.month_name
)
SELECT
    year,
    month,
    month_name,
    ROUND(total_revenue, 2) AS total_revenue,
    -- LAG() looks one row back (= previous month) in chronological order
    ROUND(LAG(total_revenue) OVER (ORDER BY year, month), 2) AS previous_month_revenue,
    ROUND(
        (total_revenue - LAG(total_revenue) OVER (ORDER BY year, month))
        / NULLIF(LAG(total_revenue) OVER (ORDER BY year, month), 0) * 100
    , 2) AS mom_growth_pct
FROM monthly_revenue
ORDER BY year, month;
