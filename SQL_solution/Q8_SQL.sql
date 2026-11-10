/* =====================================================
   Q8: Incremental load of today's batch into fact_orders
===================================================== */

-- Backup (before anything changes)
DROP TABLE IF EXISTS fact_orders_backup;
SELECT * INTO fact_orders_backup FROM fact_orders;


-- Row count BEFORE
SELECT COUNT(*) AS rows_before FROM fact_orders;


-- MERGE
MERGE INTO fact_orders AS tgt                     -- target
USING stg_orders_incr AS src                          -- source (today's batch)
    ON tgt.order_id  = src.order_id              -- match key


WHEN MATCHED AND (
       tgt.order_status <> src.order_status
    OR tgt.order_total  <> src.order_total
    )
    THEN
    UPDATE SET tgt.order_status = src.order_status,
               tgt.order_total  = src.order_total


WHEN NOT MATCHED BY TARGET THEN
    INSERT (order_id, order_date, customer_id, sales_rep_id, order_status, order_total)
    VALUES (src.order_id, src.order_date, src.customer_id,
            src.sales_rep_id, src.order_status, src.order_total)


OUTPUT $action, inserted.order_id, inserted.order_status, inserted.order_total
;

-- Row count AFTER
SELECT COUNT(*) AS rows_after FROM fact_orders;



-- Sample of updated rows: orders that came from the batch AND already existed
SELECT TOP 10 b.order_id,
       b.order_status AS old_status, f.order_status AS new_status,
       b.order_total  AS old_total,  f.order_total  AS new_total
FROM fact_orders_backup AS b
INNER JOIN fact_orders AS f ON b.order_id = f.order_id
WHERE b.order_status <> f.order_status
   OR b.order_total  <> f.order_total;

-- Check before and after merge

SELECT
    (SELECT COUNT(*) FROM fact_orders_backup) AS rows_before,
    (SELECT COUNT(*) FROM fact_orders)        AS rows_after,
    (SELECT COUNT(*) FROM fact_orders f
     WHERE NOT EXISTS (SELECT 1 FROM fact_orders_backup b
                       WHERE b.order_id = f.order_id)) AS rows_inserted;