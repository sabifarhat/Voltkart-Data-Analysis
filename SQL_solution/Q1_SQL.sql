/* =====================================================
   Q1: Top 20 completed orders by value
   Output: order_id, order_date, customer_name,
           sales_rep_name, order_total
===================================================== */

SELECT TOP 20
    o.order_id,
    o.order_date,
    c.customer_name,
    e.employee_name AS sales_rep_name,   
    o.order_total                        -- one row per order, so no SUM needed
FROM fact_orders AS o
-- INNER JOIN: checked that 0 orders have a missing customer or rep,
-- so no rows are dropped
INNER JOIN dim_customer AS c
    ON o.customer_id = c.customer_id
INNER JOIN dim_employee AS e
    ON o.sales_rep_id = e.employee_id    -- column names differ: rep id = employee id
WHERE o.order_status = 'Completed'       -- only completed orders count as revenue
ORDER BY o.order_total DESC
;                     --