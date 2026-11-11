SET STATISTICS IO, TIME ON;   -- show reads and time in the Messages tab


DROP INDEX IF EXISTS ix_fact_orders_order_date    ON fact_orders;
DROP INDEX IF EXISTS ix_fact_orders_order_id      ON fact_orders;
DROP INDEX IF EXISTS ix_fact_order_items_order_id ON fact_order_items;

-- ORIGINAL (slow) query
SELECT o.customer_id, COUNT(*) AS orders_2024,
       (SELECT SUM(oi.line_amount)
        FROM fact_order_items oi
        JOIN fact_orders o2 ON o2.order_id = oi.order_id
        WHERE o2.customer_id = o.customer_id) AS lifetime_value
FROM fact_orders o
WHERE YEAR(o.order_date) = 2024
GROUP BY o.customer_id;



-- Indexes that support the rewritten query


-- Helps orders_2024: jump to 2024 by date; customer_id is stored in the index
CREATE NONCLUSTERED INDEX ix_fact_orders_order_date
    ON fact_orders (order_date)
    INCLUDE (customer_id);

-- Helps lifetime: find orders by order_id, with customer_id stored
CREATE NONCLUSTERED INDEX ix_fact_orders_order_id
    ON fact_orders (order_id)
    INCLUDE (customer_id);

-- Helps lifetime: find order lines by order_id; line_amount is stored
CREATE NONCLUSTERED INDEX ix_fact_order_items_order_id
    ON fact_order_items (order_id)
    INCLUDE (line_amount);


-- Rewritten the same query

WITH orders_2024 AS (
    SELECT customer_id, COUNT(*) AS orders_2024
    FROM fact_orders
    WHERE order_date >= '2024-01-01' AND order_date < '2025-01-01'   -- SARGable: lets an index on order_date be used 
    GROUP BY customer_id
),
lifetime AS (
    SELECT o.customer_id, SUM(oi.line_amount) AS lifetime_value      -- calculated once per customer
    FROM fact_order_items AS oi
    INNER JOIN fact_orders AS o ON o.order_id = oi.order_id
    GROUP BY o.customer_id
)
SELECT y.customer_id, y.orders_2024, l.lifetime_value
FROM orders_2024 AS y
LEFT JOIN lifetime AS l ON l.customer_id = y.customer_id;



/* =====================================================
   Q10 Results: Before vs After
===================================================== 

   Metric                      Before     After     Change
   -------------------------   ------     -----     ------
   fact_orders logical reads     386        123      -68%
   fact_order_items reads        267        187      -30%
   Total logical reads           653        310      -53%
   CPU time (ms)                 234         79      -66%
   Elapsed time (ms)             427        141      -67%
   Rows returned               1,965      1,965      same

   Why the original was slow
   - YEAR(order_date) is non-SARGable, so an index on order_date can't be used.
   - All tables were heaps (no indexes), so every step was a full Table Scan.
   - fact_orders was scanned twice.

   What I changed
   - Replaced YEAR() with a date range (>= '2024-01-01' AND < '2025-01-01').
   - Moved lifetime value into its own CTE (for readability; not a speed fix).
   - Added nonclustered indexes with INCLUDE columns on
     fact_orders (order_date), fact_orders (order_id) and
     fact_order_items (order_id).

   How the plan changed
   - The 2024 filter changed from a Table Scan to an Index Seek.
   - Lifetime value still reads every order line, but from narrow
     indexes instead of full tables (Index Scan).
   - No Table Scans remain.
*/