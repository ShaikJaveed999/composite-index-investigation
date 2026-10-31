# Composite Index Investigation

An evidence-based PostgreSQL experiment investigating how column order affects a composite B-tree index for the Employee Reporting DB assignment.

## 1. Project Overview

This project preserves the official starter's `employees` schema, sample data, and two multi-filter queries, then compares the starter index order with a corrected order. The experiment records real PostgreSQL plans; it does not assume that an index will be used just because it exists.

## 2. Assignment Objective

The objective is to compare the existing composite index against an index whose leading key matches the query's equality filter, and then evaluate the effect using `EXPLAIN ANALYZE` and `EXPLAIN (ANALYZE, BUFFERS)`.

## 3. Starter Project

The original assignment is [Milestone-03/Index Order Matters](https://github.com/kalviumcommunity/Project-Engineering/tree/main/Milestone-03/Index%20Order%20Matters) in the Kalvium Community Project-Engineering repository. Its provided SQL files are retained in [`db/`](./db/). The schema actually defines only `employees`; the starter README's note about other tables is not reflected in the supplied schema file.

## 4. Database Setup

Use PostgreSQL 14 or newer and a disposable database. `sql/setup.sql` drops and recreates the `employees` table, creates the starter `(salary, department)` index, loads the eight original rows, and runs `ANALYZE`.

Example commands (run from this project directory; adjust connection options for your installation):

```powershell
createdb -U postgres employee_reporting
psql -U postgres -d employee_reporting -f sql/setup.sql
```

The setup script resets the `employees` table, so do not point it at a database containing data you need to keep.

## 5. Original Query

The first original query is:

```sql
SELECT *
FROM employees
WHERE department = 'Sales'
AND salary > 50000;
```

The starter's second query filters `department = 'Engineering'` and `salary >= 70000`. Both have a department equality predicate and salary range predicate, with no join or ordering clause. Run both original queries and their plans with:

```powershell
psql -U postgres -d employee_reporting -f sql/original_query.sql
```

## 6. Incorrect Index Experiment

The starter index is `idx_salary_department` on `(salary, department)`. The experiment script explicitly recreates that order:

```powershell
psql -U postgres -d employee_reporting -f sql/incorrect_index.sql
```

The original eight-row sample produced sequential scans, so `sql/performance_analysis.sql` adds one million deterministic representative test rows before comparing plans. The script leaves sequential scans enabled and uses the same query in both index states.

## 7. Corrected Index

The corrected index is `idx_department_salary` on `(department, salary)`. It places the query's equality-filter column before its range-filter column:

```powershell
psql -U postgres -d employee_reporting -f sql/corrected_index.sql
```

## 8. Left-Most Prefix Rule

A B-tree composite index is ordered by its first key, then by subsequent keys within the values of preceding keys. Its leading columns are therefore the most directly useful for locating a constrained range. For these queries, `(department, salary)` first narrows to a department and then to the matching salary range. A salary-only predicate does not get the same direct leading-key lookup from this index.

## 9. Performance Comparison

Recorded results from the local PostgreSQL 18.4 run are in [`results/explain_analyze_results.md`](./results/explain_analyze_results.md). On the original eight rows, PostgreSQL chose sequential scans. On the 1,000,008-row test set, the wrong-order index still produced a `Parallel Seq Scan`; the corrected index produced an `Index Scan`. Both returned 702 rows, and a set comparison found zero differing rows.

The timings are actual observations from one local run, not portable benchmarks or guarantees. Planning decisions and timings can change with row distribution, statistics, PostgreSQL version, cache state, and hardware.

## 10. How to Run the Experiments

Create a disposable database and initialize it:

```powershell
createdb -U postgres employee_reporting
psql -U postgres -d employee_reporting -f sql/setup.sql
```

First run the original queries on the eight starter rows:

```powershell
psql -U postgres -d employee_reporting -f sql/original_query.sql
```

Then recreate the large dataset, compare plans using the incorrect and corrected index, and verify that result rows are identical:

```powershell
psql -U postgres -d employee_reporting -f sql/performance_analysis.sql
```

The performance script truncates and repopulates `employees` with the original eight sample rows plus one million generated rows. Run it only in the disposable assignment database. It calls both `EXPLAIN ANALYZE` and `EXPLAIN (ANALYZE, BUFFERS)` for the query in each index state.

The individual index scripts can also be run separately after setup. Run [`sql/incorrect_index.sql`](./sql/incorrect_index.sql) or [`sql/corrected_index.sql`](./sql/corrected_index.sql), then execute the query from [`sql/original_query.sql`](./sql/original_query.sql) with either form:

```sql
EXPLAIN ANALYZE
SELECT *
FROM employees
WHERE department = 'Sales'
AND salary > 50000;

EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM employees
WHERE department = 'Sales'
AND salary > 50000;
```

## 11. Project Structure

```text
.
├── Changes.md
├── README.md
├── VIDEO_EXPLANATION.md
├── db/
│   ├── queries.sql
│   ├── sample_data.sql
│   └── schema.sql
├── results/
│   └── explain_analyze_results.md
└── sql/
    ├── corrected_index.sql
    ├── incorrect_index.sql
    ├── original_query.sql
    ├── performance_analysis.sql
    └── setup.sql
```

See [`Changes.md`](./Changes.md) for the full analysis and [`VIDEO_EXPLANATION.md`](./VIDEO_EXPLANATION.md) for the screen-recording script.

## 12. Conclusion

For the supplied equality-plus-range filter pattern, placing `department` before `salary` aligned the B-tree with the query and resulted in an index scan on the generated dataset. The plan and row-equivalence evidence is documented rather than assumed.
