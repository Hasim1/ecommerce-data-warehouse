/* =====================================================================
   Query F — Discount Impact Analysis
   ---------------------------------------------------------------------
   Business question : Do discounts actually pay off? How much revenue
                       and profit do we give up per discount level, and
                       do discounted lines sell more units?
   Techniques        : CTE with CASE-based bucketing, aggregate
                       comparison across discount bands.
   Engine            : Oracle 12cR2+ (part of the Oracle SQL Developer
                       port of this project; syntax is identical to
                       the PostgreSQL original)
   ===================================================================== */

WITH line_discount AS (
    SELECT
        f.*,
        -- Classify every order line into a discount band based on the
        -- discount as a percentage of the gross (pre-discount) amount
        CASE
            WHEN f.discount_amount = 0                             THEN '1. No discount'
            WHEN f.discount_amount / NULLIF(f.gross_amount, 0) <= 0.10 THEN '2. Low (0-10%)'
            WHEN f.discount_amount / NULLIF(f.gross_amount, 0) <= 0.20 THEN '3. Medium (10-20%)'
            ELSE                                                        '4. High (20%+)'
        END AS discount_band
    FROM fact_sales f
)
SELECT
    discount_band,
    COUNT(*)                                         AS order_lines,
    SUM(quantity)                                    AS units_sold,
    ROUND(AVG(quantity), 2)                          AS avg_units_per_line,
    ROUND(SUM(gross_amount), 2)                      AS gross_revenue,
    ROUND(SUM(discount_amount), 2)                   AS discount_given,
    ROUND(SUM(total_amount), 2)                      AS net_revenue,
    ROUND(SUM(profit_amount), 2)                     AS profit,
    -- Margin comparison across bands shows how deeply discounts
    -- eat into profitability
    ROUND(SUM(profit_amount)
          / NULLIF(SUM(total_amount), 0) * 100, 2)   AS profit_margin_pct
FROM line_discount
GROUP BY discount_band
ORDER BY discount_band;
