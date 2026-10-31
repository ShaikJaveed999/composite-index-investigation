# Video Explanation Script

**Target length:** 3–5 minutes

**Recording status:** Not recorded. This file is a script only.

> Turn on your camera and remain clearly visible while explaining, as required by the assignment. Show the real database output on screen; do not present this script as a recording.

## 0:00–0:30 — Introduction

“Hello, this is my Index Order Matters Challenge 3 investigation. I used the actual Employee Reporting DB files from the official Project-Engineering starter. I’ll compare its composite index order with an order that matches the query filters.”

Show the project directory and `db/schema.sql`. Point out that the provided schema creates the `employees` table and the original index on `(salary, department)`.

## 0:30–1:10 — Original query and small-table plan

Open `db/queries.sql` and show:

```sql
SELECT *
FROM employees
WHERE department = 'Sales'
AND salary > 50000;
```

Run or show the actual output from `sql/original_query.sql`. Explain that the starter sample has only eight rows and PostgreSQL chose a sequential scan; that is reasonable for a tiny table, so the sample alone does not prove that the index is ineffective.

## 1:10–1:55 — Incorrect index and representative data

Show `sql/incorrect_index.sql` and its `(salary, department)` order. Explain that salary is a range predicate and is the leading index key in the starter. Then show `sql/performance_analysis.sql` and explain that it adds one million deterministic test rows because the original sample is too small for a useful plan comparison.

## 1:55–2:40 — Actual incorrect-order plan

Show the `Parallel Seq Scan` in `results/explain_analyze_results.md`. Explain that the measured salary range matches a large share of the rows, so PostgreSQL chose to scan the table rather than use the salary-first index. Read the actual measured execution and planning times from the results file; mention that they are from this local run and can vary.

## 2:40–3:25 — Corrected index and result check

Show `sql/corrected_index.sql` and the `(department, salary)` order. Show the actual `Index Scan` with both filter terms in `Index Cond`. Then show the results comparison: 702 rows for each index state and zero differing rows.

## 3:25–4:05 — Left-Most Prefix Rule

“A multicolumn B-tree is ordered by its leading key first. With department first, PostgreSQL can locate the requested department and then apply the salary range within that part of the index. This is why key order should reflect the query's leading equality filters and then its range condition. The planner still decides whether an index is worthwhile for the actual data.”

## 4:05–4:35 — Changes and conclusion

Open `Changes.md`, briefly show the plan comparison and conclusion. Finish by explaining that the corrected order was better for this measured query and dataset, while a different distribution or table size can produce a different plan.

## Recording checklist

- Turn on the camera and make sure you are clearly visible while speaking.
- Show real output from the local PostgreSQL session and the recorded results.
- Keep the explanation between 3 and 5 minutes.
- Save the actual screen recording and submit it separately; no video file has been created by this project.
- The starter README also requests screenshots of the before-and-after plans; capture those from your own live run if they are required for submission.
