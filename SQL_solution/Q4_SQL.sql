/* =====================================================
   Q4: Monthly completed revenue with running total
       and month-over-month % change
   Output: order_month (YYYY-MM), monthly_revenue,
           running_total, mom_pct_change
===================================================== */

-- Step 1: aggregate to one row per month FIRST
WITH monthly_rev AS (
    SELECT CONVERT(char(7), order_date, 126) AS order_month,   -- style 126 = ISO date, char(7) keeps 'YYYY-MM'
           SUM(order_total)                  AS monthly_revenue -- one row per order, so order_total is safe
    FROM fact_orders
    WHERE order_status = 'Completed'                            -- only completed orders count as revenue
    GROUP BY CONVERT(char(7), order_date, 126)
)
,

-- Step 2: window functions over the monthly rows
trend AS (
    SELECT order_month,
           monthly_revenue,
           SUM(monthly_revenue) OVER (
               ORDER BY order_month
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW  -- Row is explicit frame: all prior months + this one
           ) AS running_total,
           LAG(monthly_revenue) OVER (ORDER BY order_month) AS prev_month_revenue  -- NULL for the first month
    FROM monthly_rev
)
-- Step 3: month-over-month % change
SELECT order_month,
       monthly_revenue,
       running_total,
       ROUND(
           (monthly_revenue - prev_month_revenue) * 100.0
           / NULLIF(prev_month_revenue, 0),                     -- avoids divide-by-zero
       2) AS mom_pct_change                                     
FROM trend
ORDER BY order_month;