# Composite Index Investigation

## 1. Assignment Overview

This investigation uses the PostgreSQL employee-reporting assignment from the official [Project-Engineering starter repository](https://github.com/kalviumcommunity/Project-Engineering/tree/main/Milestone-03/Index%20Order%20Matters). The starter creates one `employees` table, eight sample rows, and the composite B-tree index `idx_salary_department` on `(salary, department)`.

The goal is to compare that starter index with an ordering aligned to the filters in the provided queries. The table definition is unchanged. The performance experiment adds one million deterministic test rows without changing the schema.

## 2. Original Query Analysis

The first provided query is:

```sql
SELECT *
FROM employees
WHERE department = 'Sales'
AND salary > 50000;
```

The second is:

```sql
SELECT *
FROM employees
WHERE department = 'Engineering'
AND salary >= 70000;
```

Both use equality on `department` and a range condition on `salary`. Neither query has a join or an `ORDER BY`. In both, `department` is the useful leading equality condition and `salary` is the range condition.

## 3. Original Index Analysis

The starter defines:

```sql
CREATE INDEX idx_salary_department ON employees(salary, department);
```

This puts the `salary` range before the `department` equality. A B-tree ordered by salary first cannot directly narrow the scan to the requested department-and-salary range as effectively as one ordered by department first. The exact planner decision depends on table size and data distribution; an index definition alone does not guarantee an index scan.

## 4. Incorrect Composite Index

The original `(salary, department)` definition was retained as the deliberately less useful ordering. The comparison script recreates this index before running the incorrect-order experiment, so it works from either the setup state or a previous experiment state.

## 5. Observed Query Plan

With the original eight sample rows, PostgreSQL selected a `Seq Scan` even though the starter index existed. It returned 2 Sales rows and 3 Engineering rows. It examined the eight-row table and rejected 6 rows for the first query and 5 for the second. This tiny table is not sufficient to demonstrate an index's usefulness.

With one million generated rows added to those eight sample rows, the query using the incorrect index order still planned a `Parallel Seq Scan`. It returned 702 rows and removed 999,306 rows by the filter across its three loops. The full plan, including planning/execution times and buffers, is recorded in [results/explain_analyze_results.md](./results/explain_analyze_results.md).

## 6. Why the Incorrect Index Was Ineffective

The generated salary distribution makes `salary > 50000` match a large fraction of rows. With salary as the first index key, PostgreSQL would have to consider a broad salary range before applying the department condition. The measured plan shows the planner chose a parallel sequential scan rather than reading that broad range through the index.

This result is specific to the measured query, dataset, and PostgreSQL instance. It is not a claim that PostgreSQL can never use a later index column or that the incorrect index is unusable for every query.

## 7. Corrected Composite Index

The corrected index is:

```sql
CREATE INDEX idx_department_salary ON employees(department, salary);
```

It puts the equality condition first and the range condition second. For the generated dataset and first query, PostgreSQL used an `Index Scan` with both conditions shown in the `Index Cond`.

## 8. Before and After Query Plan Comparison

For the same 1,000,008-row dataset and query:

| Index | Observed plan | Actual rows | Execution time in recorded run |
|---|---|---:|---:|
| `(salary, department)` | `Parallel Seq Scan` | 702 | 144.886 ms |
| `(department, salary)` | `Index Scan` | 702 | 2.397 ms |

The buffer-enabled plans are captured verbatim in [results/explain_analyze_results.md](./results/explain_analyze_results.md). A result comparison returned 702 rows for each index and 0 differing rows. These are measurements from one run on the local PostgreSQL 18.4 test instance; execution time and buffer counts are workload-, cache-, and machine-dependent, not a universal performance guarantee.

## 9. Left-Most Prefix Rule

A multicolumn B-tree is ordered first by its first key, then by its second key within equal first-key values, and so on. Queries that constrain the leading key columns can therefore identify a narrow part of the index. In the corrected index, PostgreSQL can first locate `department = 'Sales'`, then apply `salary > 50000` within that department's part of the index.

An index on `(department, salary)` also has a useful leading `department` key for department-only filters. A query that constrains only `salary` does not have the same direct leading-key lookup in that index. PostgreSQL planner capabilities and data distribution can affect whether it uses an index, so the plan should be checked with `EXPLAIN`.

## 10. Performance Observations

- On the original eight rows, sequential scans were selected for both queries. This is reasonable for such a small table and does not by itself prove a column-order problem.
- On the generated dataset, the salary-first index was not selected for the first query; the plan was a parallel sequential scan.
- With department first, PostgreSQL used an index scan and reported the matching department and salary range as its index condition.
- The test did not disable sequential scans. Both index states were tested with the same query and data.
- The index change did not change the query result: 702 rows in each state, with zero row differences.

## 11. Conclusion

For the starter queries' equality-on-department plus range-on-salary pattern, `(department, salary)` is the better-aligned composite B-tree order. The actual plan comparison supports that conclusion for the recorded test dataset. The original small sample remains useful for understanding the assignment, but is too small to make the planner choose an index scan.
