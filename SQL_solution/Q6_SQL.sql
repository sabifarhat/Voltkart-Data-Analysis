/* =====================================================
   Q6: All categories under 'Computers', at any depth
   Output: category_id, category_name, depth_level, category_path
===================================================== */

WITH depth AS (
    -- Anchor: start at Computers
    SELECT category_id,
           parent_category_id,
           category_name,
           0 AS depth_level,
           CAST(category_name AS NVARCHAR(MAX)) AS category_path
    FROM dim_category
    WHERE category_name = 'Computers'

    UNION ALL

    -- Recursive: find the children of the previous pass
    SELECT c.category_id,
           c.parent_category_id,
           c.category_name,
           d.depth_level + 1,                                                  -- one level deeper
           CAST(d.category_path + ' > ' + c.category_name AS NVARCHAR(MAX))   -- extend the path
    FROM dim_category AS c
    INNER JOIN depth AS d
        ON c.parent_category_id = d.category_id
)
SELECT category_id,
       category_name,
       depth_level,
       category_path
FROM depth
ORDER BY category_path;   -- children listed under their parent

/* Approach: Recursive CTE. The anchor is 'Computers' (depth 0); each pass joins
   children on parent_category_id, adding depth + 1 and ' > ' + name to the path.
   CAST to NVARCHAR(MAX) so both parts have matching types.

   Insight: shows the full Computers branch at any depth in one view.
   Change the anchor name to explore any other branch. */