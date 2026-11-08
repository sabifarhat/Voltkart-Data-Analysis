/* =====================================================
   Q3: Top 3 products by completed revenue in each category
   Output: category_name, product_name, total_revenue, revenue_rank
===================================================== */

-- Step 1: total completed revenue per product, labelled with its category
WITH product_revenue AS (
    SELECT cat.category_name,
           p.product_name,
           SUM(oi.line_amount) AS total_revenue      -- line_amount = quantity * unit_price
    FROM fact_order_items AS oi
    INNER JOIN fact_orders  AS o   ON o.order_id      = oi.order_id     -- to get order status
    INNER JOIN dim_product  AS p   ON p.product_id    = oi.product_id
    INNER JOIN dim_category AS cat ON cat.category_id = p.category_id   -- product's leaf category
    WHERE o.order_status = 'Completed'               -- only completed orders count as revenue
    GROUP BY cat.category_name, p.product_name
),

-- Step 2: rank products within each category (rank restarts per category)
ranked AS (
    SELECT category_name,
           product_name,
           total_revenue,
           RANK() OVER (
               PARTITION BY category_name            -- separate ranking per category
               ORDER BY total_revenue DESC           -- highest revenue = rank 1
           ) AS revenue_rank
    FROM product_revenue
)

-- Step 3: keep the top 3 per category.
-- A window function can't be filtered in the same SELECT's WHERE,
-- which is why the rank is computed in its own CTE first.
SELECT category_name,
       product_name,
       total_revenue,
       revenue_rank
FROM ranked
WHERE revenue_rank <= 3
ORDER BY category_name, revenue_rank;