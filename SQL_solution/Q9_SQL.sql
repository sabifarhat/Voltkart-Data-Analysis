/* =====================================================
   Q9: Apply the CDC product feed to dim_product
   The catalogue source now emits a change feed (cdc_product_changes)
   with operation codes. Apply it to dim_product in a single MERGE:
   I inserts a new product, U updates an existing one, D deletes it.
   Acceptance: one MERGE handling all three operations, plus a
   verification query showing inserted, updated and deleted products.
===================================================== */

-- Backup (run ONCE, before the MERGE). Commented out so a re-run can't overwrite it.
-- DROP TABLE IF EXISTS dim_product_backup;
-- SELECT * INTO dim_product_backup FROM dim_product;


/* -----------------------------------------------------
   Explore the CDC feed before applying it
   Expected: U and D → already exist in dim_product
             I       → don't exist yet (new products)
----------------------------------------------------- */
SELECT c.operation,                                         -- I, U or D
       COUNT(*) AS change_rows,                             -- changes of this type
       SUM(CASE WHEN p.product_id IS NOT NULL
                THEN 1 ELSE 0 END) AS exists_in_target      -- how many match an existing product
FROM cdc_product_changes AS c
LEFT JOIN dim_product AS p                                  -- LEFT: keep every feed row
    ON p.product_id = c.product_id
GROUP BY c.operation;


/* -----------------------------------------------------
   One MERGE that honours the operation codes
----------------------------------------------------- */
DECLARE @log TABLE (action NVARCHAR(10), new_id BIGINT, old_id BIGINT);  -- captures what the MERGE did

MERGE INTO dim_product AS tgt                               -- target
USING cdc_product_changes AS src                            -- the CDC feed
    ON tgt.product_id = src.product_id                      -- match key

WHEN MATCHED AND src.operation = 'U' THEN                   -- update
    UPDATE SET tgt.product_name = src.product_name,
               tgt.category_id  = src.category_id,
               tgt.unit_price   = src.unit_price,
               tgt.unit_cost    = src.unit_cost,
               tgt.launch_date  = src.launch_date

WHEN MATCHED AND src.operation = 'D' THEN                   -- delete
    DELETE

WHEN NOT MATCHED BY TARGET AND src.operation = 'I' THEN     -- insert
    INSERT (product_id, product_name, category_id, unit_price, unit_cost, launch_date)
    VALUES (src.product_id, src.product_name, src.category_id,
            src.unit_price, src.unit_cost, src.launch_date)

OUTPUT $action, inserted.product_id, deleted.product_id
INTO @log                                                   -- save the output for counting
;

-- Counts per action
SELECT action, COUNT(*) AS row_count
FROM @log
GROUP BY action;


/* -----------------------------------------------------
   Verification, backup (before) vs dim_product (after)
----------------------------------------------------- */
-- Inserted: in dim_product now, not in the backup
SELECT 'INSERTED' AS change_type, p.product_id, p.product_name, p.unit_price
FROM dim_product AS p
WHERE NOT EXISTS (SELECT 1 FROM dim_product_backup b WHERE b.product_id = p.product_id)

UNION ALL

-- Updated: in both, but values differ
SELECT 'UPDATED', p.product_id, p.product_name, p.unit_price
FROM dim_product AS p
INNER JOIN dim_product_backup AS b ON b.product_id = p.product_id
WHERE b.product_name <> p.product_name
   OR b.category_id  <> p.category_id
   OR b.unit_price   <> p.unit_price
   OR b.unit_cost    <> p.unit_cost
   OR b.launch_date  <> p.launch_date

UNION ALL

-- Deleted: in the backup, gone from dim_product
SELECT 'DELETED', b.product_id, b.product_name, b.unit_price
FROM dim_product_backup AS b
WHERE NOT EXISTS (SELECT 1 FROM dim_product p WHERE p.product_id = b.product_id)

ORDER BY change_type, product_id;


/* Approach: one MERGE driven by the CDC operation code. U → update and
   D → delete on matched rows; I → insert on unmatched rows. Explored the
   feed first to confirm the codes matched the target. Took a backup
   for before/after verification.

   Result: 20 updated, 10 inserted, 5 deleted, matching the feed exactly.

   Insight: CDC captures deletes, which a watermark-based incremental load
   cannot (a deleted row has no ModifiedDate). In production, processed
   changes would be tracked, e.g. by the last change_id, so they aren't re-applied. */