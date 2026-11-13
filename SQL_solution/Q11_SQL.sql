/* =====================================================
   Q11 (Bonus): Customer loyalty streaks
   The retention team wants loyalty streaks. For each customer,
   find the longest run of consecutive calendar months in which
   they placed at least one completed order.
   Output: customer_id, customer_name, longest_streak_months
===================================================== */

-- One row per customer per active month (completed orders only)
WITH cust_cte AS (
    SELECT customer_id,
           FORMAT(order_date, 'MMM yyyy')            AS order_month_year,  -- readable label
           YEAR(order_date) * 12 + MONTH(order_date) AS month_num          -- consecutive months differ by 1
    FROM fact_orders
    WHERE order_status = 'Completed'
    GROUP BY customer_id,
             FORMAT(order_date, 'MMM yyyy'),
             YEAR(order_date) * 12 + MONTH(order_date)                     -- several orders in a month count once
),

-- Label each run of consecutive months 
island AS (
    SELECT *,
           month_num - ROW_NUMBER() OVER (
               PARTITION BY customer_id
               ORDER BY month_num
           ) AS island                                                     -- same value = same unbroken streak
    FROM cust_cte
),

-- Length of each streak
streak AS (
    SELECT customer_id,
           island,
           COUNT(*) AS streak_months
    FROM island
    GROUP BY customer_id, island
)

-- Longest streak per customer
SELECT s.customer_id,
       c.customer_name,
       MAX(s.streak_months) AS longest_streak_months
FROM streak AS s
INNER JOIN dim_customer AS c
    ON c.customer_id = s.customer_id
GROUP BY s.customer_id, c.customer_name
ORDER BY longest_streak_months DESC;


-- Verification: customers with at least one completed order
-- (should equal the main query's row count)
SELECT COUNT(DISTINCT customer_id) AS customers_with_completed_orders
FROM fact_orders
WHERE order_status = 'Completed';


/* Approach: Each active month becomes a number
   (year * 12 + month). Subtracting ROW_NUMBER() gives the same value
   for consecutive months, so each streak can be grouped and counted.
   The longest streak per customer is the MAX of those counts.
   Tested on customer 500000: streaks of 3 (Jan–Mar 2023) and
   23 (May 2023 – Mar 2025), so longest = 23.

   Insight: the data covers Jan 2023 – Mar 2025 (27 months), so a
   streak of 27 means the customer bought every single month. These
   are the most loyal customers, a natural target for loyalty rewards.
   Shorter streaks highlight customers whose buying habit broke, who
   are candidates for win-back campaigns. */