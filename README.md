# Voltkart: Advanced SQL for Modern Data Engineering

🎥 **[Video walkthrough](https://drive.google.com/file/d/1mBXIlbEfsyZMxC8ismiRvPOLprp2Dsb_/view?usp=sharing)**

## Problem Statement
Voltkart is a fast-growing online electronics and appliances retailer in India that has scaled from a niche store to millions of orders. The nightly job still rebuilds reporting tables with full reloads, which has become slow and fragile.

The data team needs to:
- move from **nightly full reloads to incremental, change-driven loading**, and
- deliver **reporting that answers real business questions**.

## Resources Provided
- A relational schema: orders and order-line facts, a daily staging batch of new and changed orders, customers, a product catalogue on a recursive category tree, a sales org chart, and a change-data-capture (CDC) feed for products
- A full data dictionary

**Tools:** SQL Server (T-SQL), SSMS

## Repository Structure
| Folder | Contents |
|---|---|
| `SQL_solution/` | One `.sql` file per question, with comments, approach and results |
| `screenshot/` | Output for each question; Q10 includes before/after execution plans and STATISTICS IO |

## Solutions by Stakeholder

| # | Stakeholder | Business question | Approach | Key result |
|---|---|---|---|---|
| Q1 | Commercial | Top 20 completed orders by value, with customer and sales rep | Joins + `TOP 20`, filtered to Completed | Top 20 orders with tie-breaker for a stable result |
| Q2 | Marketing | Customers who registered but never ordered | `NOT EXISTS` anti-join (NULL-safe, unlike `NOT IN`) | 0 rows: validated that all 2,000 customers have ordered |
| Q3 | Merchandising | Top 3 products per category by completed revenue | Revenue per product, then `RANK()` per category | `RANK` keeps ties at 3rd place |
| Q4 | Finance | Monthly revenue, running total and MoM % change | Monthly aggregate, then `SUM() OVER` and `LAG()` | First month MoM is NULL by design |
| Q5 | CRM | Customer quartiles by lifetime completed spend | `NTILE(4)` by spend (1 = top spenders) | Spend drops sharply from Q1 to Q4 |
| Q6 | Catalogue | All categories under 'Computers', with depth and path | Recursive CTE: anchor at Computers, recurse on `parent_category_id` | Full branch at any depth, with readable path |
| Q7 | Sales leadership | Team revenue rolled up the org chart | Recursive CTE pairing each employee with their whole subtree, then `SUM` | CEO total = total completed revenue (validated) |
| Q8 | Platform | Incremental load of today's batch | One `MERGE`: update changed orders, insert new ones | 30,000 → 30,500 rows (500 inserted) |
| Q9 | Catalogue | Apply the CDC feed to `dim_product` | One `MERGE` honouring I / U / D codes | 20 updated, 10 inserted, 5 deleted |
| Q10 | Platform | Speed up a slow report | SARGable date range + covering indexes | Logical reads 653 → 310 (−53%) |
| Q11 | Retention (bonus) | Longest streak of consecutive buying months | Gaps-and-islands with `ROW_NUMBER()` | Max 27 = bought every month in the data |

## Highlights

### Recursive queries (Q6, Q7)
A recursive CTE starts from an **anchor** row and uses `UNION ALL` with a **recursive part** that joins back to itself, finding the next level on each pass and stopping when no rows are found. This removes the need for hand-written joins per level, which break when the tree changes depth.
- **Q6:** anchored at *Computers*, tracking depth and building a path like `Computers > Laptops > Gaming Laptops`.
- **Q7:** every employee is the root of their own team. The recursion carries the team owner down each level, then sums each member's completed orders per owner. Tested on one regional manager's team (15 people) before running for all.

### MERGE and CDC (Q8, Q9)
- **Q8:** `WHEN MATCHED AND (status or total changed)` updates only rows that actually changed; `WHEN NOT MATCHED BY TARGET` inserts new orders. Verified with a backup: row counts before vs after, plus a sample of old vs new values.
- **Q9:** the CDC operation code drives the action. U → update, D → delete (matched rows), I → insert (unmatched rows). The feed was explored first to confirm the codes matched the target. CDC captures **deletes**, which a timestamp-based incremental load cannot.

### Query tuning (Q10)

| Metric | Before | After | Change |
|---|---|---|---|
| fact_orders logical reads | 386 | 123 | −68% |
| fact_order_items logical reads | 267 | 187 | −30% |
| **Total logical reads** | **653** | **310** | **−53%** |
| CPU time (ms) | 234 | 79 | −66% |
| Elapsed time (ms) | 427 | 141 | −67% |

*Logical reads = the number of data pages SQL Server read. Fewer reads means less work.*

- **Problem:** `YEAR(order_date) = 2024` wraps the column in a function, so SQL Server can't use an index on it. This is called **non-SARGable**. The tables also had no indexes (they were **heaps**), so SQL Server read every row of every table (a **Table Scan**) and read `fact_orders` twice.

- **Fix 1: SARGable date range.** Replaced `YEAR()` with `order_date >= '2024-01-01' AND order_date < '2025-01-01'`. The column is left untouched, so an index on it can be used.

- **Fix 2: indexes.** Added three **nonclustered indexes**: separate, sorted lookup lists on chosen columns, like the index at the back of a book. Each one stores only the columns the query needs (using `INCLUDE`), which makes it a **narrow index**: much smaller than the full table, so fewer pages to read.

- **How the plan changed:**
  - The 2024 filter became an **Index Seek**: SQL Server jumps straight to the 2024 rows instead of reading the whole table.
  - Lifetime value still needs every order line, but now reads the **narrow indexes** instead of the full tables.
  - No full Table Scans remain.

- Before/after plans and STATISTICS IO output are in `screenshot/`.

## Key Learnings
- Choose the tool that fits: **EXISTS** filters, **JOIN** widens, **recursion** handles unknown depth.
- `MERGE` applies inserts, updates and deletes **atomically** in one statement; always verify with before/after checks.
- Performance comes from **SARGable predicates and indexes**, not from rewriting with CTEs (CTEs are for readability).
- Validate every result: row counts, totals and known test cases.
