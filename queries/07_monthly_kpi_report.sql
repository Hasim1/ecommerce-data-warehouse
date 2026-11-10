/* =====================================================================
   Query G — Monthly KPI Report
   ---------------------------------------------------------------------
   Business question : One consolidated management report: how did the
                       business perform each month across all core KPIs?
   KPIs              : Total revenue, total orders, average order value,
                       units sold, active customers, profit, margin.
   Techniques        : JOIN to date dimension, COUNT(DISTINCT),
                       derived KPIs from aggregates.
   Engine            : PostgreSQL (SQL Server: identical syntax)

   This is the query a BI dashboard (Power BI / Tableau) would be
   built on top of.
   ===================================================================== */

SELECT
    d.year,
    d.month,
    d.month_name,
    ROUND(SUM(f.total_amount), 2)                    AS total_revenue,
    COUNT(DISTINCT f.order_id)                       AS total_orders,
    ROUND(SUM(f.total_amount)
          / COUNT(DISTINCT f.order_id), 2)           AS avg_order_value,
    SUM(f.quantity)                                  AS units_sold,
    COUNT(DISTINCT f.customer_key)                   AS active_customers,
    ROUND(SUM(f.profit_amount), 2)                   AS total_profit,
    ROUND(SUM(f.profit_amount)
          / NULLIF(SUM(f.total_amount), 0) * 100, 2) AS profit_margin_pct
FROM fact_sales f
JOIN dim_date d ON d.date_key = f.date_key
GROUP BY d.year, d.month, d.month_name
ORDER BY d.year, d.month;
