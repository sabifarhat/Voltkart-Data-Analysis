/* =====================================================
   Q7: Team revenue rolled up the org chart
   For every employee: completed revenue of themselves
   plus everyone under them, at any depth.
   Output: employee_id, employee_name, role, team_total_revenue
===================================================== */

WITH depth AS (
    -- Anchor: every employee owns a team that starts with themselves
    SELECT employee_id AS team_owner_id,
           employee_id,
           employee_name,
           0 AS depth_level,
           CAST(employee_name AS NVARCHAR(MAX)) AS team_path
    FROM dim_employee

    UNION ALL

    -- Recursive: add the direct reports of the last-found employee
    SELECT t.team_owner_id,                                              -- owner copied down unchanged
           e.employee_id,                                                -- new team member
           e.employee_name,
           t.depth_level + 1,
           CAST(t.team_path + ' > ' + e.employee_name AS NVARCHAR(MAX))
    FROM dim_employee AS e
    INNER JOIN depth AS t
        ON e.manager_id = t.employee_id                                  -- walk one level down
)
SELECT emp.employee_id,
       emp.employee_name,
       emp.role,
       ISNULL(ROUND(SUM(f.order_total),0), 0) AS team_total_revenue
FROM depth AS d
LEFT JOIN fact_orders AS f                       -- LEFT: keep employees with no completed orders
    ON f.sales_rep_id = d.employee_id
   AND f.order_status = 'Completed'              -- filter in ON so the LEFT JOIN is preserved
INNER JOIN dim_employee AS emp
    ON emp.employee_id = d.team_owner_id         -- owner's name and role
GROUP BY emp.employee_id, emp.employee_name, emp.role
ORDER BY team_total_revenue DESC
OPTION (MAXRECURSION 10);

/* Approach: Recursive CTE pairs every employee (team owner) with everyone
   below them, including themselves. Each member is joined to their
   completed orders and summed per owner. LEFT JOIN + ISNULL keeps employees
   with no sales at 0.
   Check: the CEO's total equals overall completed revenue.

   Insight: one view of performance at every level (rep, team lead,
   regional manager, CEO). Leadership can compare teams at the same level
   and see which branches drive revenue. */


   ----------------------------------------------------------------------------------------------------------

   /* -----------------------------------------------------
   Test 1: team 44 (Gaurav Gupta, Regional Manager)
   Lists every member of his team. Expected: himself, 3 team leads
   and 11 reps across depths 0-2.
----------------------------------------------------- */
WITH depth AS (
    SELECT employee_id AS team_owner_id, employee_id, employee_name,
           0 AS depth_level, CAST(employee_name AS NVARCHAR(MAX)) AS team_path
    FROM dim_employee
    UNION ALL
    SELECT t.team_owner_id, e.employee_id, e.employee_name, t.depth_level + 1,
           CAST(t.team_path + ' > ' + e.employee_name AS NVARCHAR(MAX))
    FROM dim_employee AS e
    INNER JOIN depth AS t ON e.manager_id = t.employee_id
)
SELECT *
FROM depth
WHERE team_owner_id = 44
ORDER BY team_path;


/* -----------------------------------------------------
   Test 2: the CEO's team_total_revenue (top row of the main query)
   should equal total completed revenue, since everyone reports to the CEO.
----------------------------------------------------- */
SELECT SUM(order_total) AS total_completed_revenue
FROM fact_orders
WHERE order_status = 'Completed';