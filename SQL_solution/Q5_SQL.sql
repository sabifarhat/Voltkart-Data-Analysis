/* =====================================================
   Q5: Customer spend quartiles
   Split customers into 4 quartiles by lifetime completed spend.
   Output: spend_quartile, customer_count, avg_lifetime_spend
===================================================== */
USE Voltkart;

-- Lifetime completed spend per customer
WITH spend AS (
    SELECT customer_id,
           SUM(order_total) AS lifetime_spend      -- keep full precision; round at the end
    FROM fact_orders
    WHERE order_status = 'Completed'               -- only real revenue counts
    GROUP BY customer_id
),

-- Split customers into 4 equal-sized groups
customer_quartile AS (
    SELECT customer_id,
           lifetime_spend,
           NTILE(4) OVER (ORDER BY lifetime_spend DESC) AS spend_quartile  -- 1 = top spenders
    FROM spend
)

-- One row per quartile
SELECT spend_quartile,
       COUNT(*)                     AS customer_count,
       ROUND(AVG(lifetime_spend), 0) AS avg_lifetime_spend
FROM customer_quartile
GROUP BY spend_quartile
ORDER BY spend_quartile;

/* -----------------------------------------------------
   Approach
   - Summed completed orders per customer: completed = real revenue,
     the right basis for loyalty and rewards targeting.
   - NTILE(4) ordered by spend DESC, so quartile 1 = highest-value customers.
   - Aggregated per quartile with GROUP BY (not window functions),
     so the output is one summary row per quartile.
   - Customers with no completed orders are excluded by design.

   Result & insight
   - Average spend drops sharply from Quartile 1 to Quartile 4:
     a small group of top customers drives a large share of revenue.
   - Recommendation: protect Quartile 1 with loyalty perks and early
     access; nurture Quartiles 2-3 with targeted offers to move them up;
     use low-cost win-back campaigns for Quartile 4.
----------------------------------------------------- */