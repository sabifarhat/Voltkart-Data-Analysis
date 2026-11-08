/* =====================================================
   Q2: Customers who registered but never placed an order
   Marketing wants to re-engage registered customers who never bought.
   Output: customer_id, customer_name, signup_date
===================================================== */

-- Anti-join: keep customers with NO matching order.
-- NOT EXISTS (not NOT IN): NOT IN returns zero rows if the subquery
-- contains a NULL. NOT EXISTS is NULL-safe and stops at the first match.
SELECT c.customer_id,
       c.customer_name,
       c.signup_date
FROM dim_customer AS c
WHERE NOT EXISTS (
    SELECT 1                              -- columns are never read; only existence matters
    FROM fact_orders AS o
    WHERE o.customer_id = c.customer_id   -- correlated: checked for each customer
)
ORDER BY c.customer_id;

-- Result: 0 rows.


/* -----------------------------------------------------
   Validation: why the result is empty
   All 2,000 customers appear in fact_orders,
   so no customer has "never ordered".
----------------------------------------------------- */
SELECT
    (SELECT COUNT(*) FROM dim_customer)                   AS total_customers,       -- 2000
    (SELECT COUNT(DISTINCT customer_id) FROM fact_orders) AS customers_with_orders; -- 2000