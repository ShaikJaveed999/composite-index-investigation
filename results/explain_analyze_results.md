# Recorded EXPLAIN Results

These are actual results from the local PostgreSQL 18.4 test run on Windows. The tests used an isolated temporary PostgreSQL cluster on `127.0.0.1:55439`; the installed PostgreSQL service was not modified. The test scripts did not disable sequential scans.

## Queries and dataset

The primary query is the starter query:

```sql
SELECT *
FROM employees
WHERE department = 'Sales'
AND salary > 50000;
```

The second starter query is:

```sql
SELECT *
FROM employees
WHERE department = 'Engineering'
AND salary >= 70000;
```

`sql/setup.sql` created the original table and index and loaded the eight starter rows. `sql/performance_analysis.sql` then added one million deterministic generated rows, for **1,000,008 total rows**, and ran `ANALYZE`.

## Original eight-row sample

With the starter `(salary, department)` index, the first query returned 2 rows and the second returned 3. Both plans were sequential scans. Each scanned all 8 rows: 6 rows were removed by the first query's filter and 5 by the second.

The captured `EXPLAIN ANALYZE` output for the first query was:

```text
Seq Scan on employees  (cost=0.00..1.12 rows=2 width=26) (actual time=0.066..0.071 rows=2.00 loops=1)
  Filter: ((salary > '50000'::numeric) AND ((department)::text = 'Sales'::text))
  Rows Removed by Filter: 6
  Buffers: shared hit=1
Planning:
  Buffers: shared hit=108
Planning Time: 5.003 ms
Execution Time: 0.151 ms
```

Its explicit `EXPLAIN (ANALYZE, BUFFERS)` run also used a sequential scan, returned 2 rows, removed 6 rows, and reported 1 shared buffer hit, 0.285 ms planning time, and 0.075 ms execution time.

For the Engineering query, the captured `EXPLAIN ANALYZE` plan was a `Seq Scan`, actual rows 3, rows removed 5, 0.438 ms planning time, and 0.071 ms execution time. Its explicit buffer-enabled run was also a `Seq Scan`, actual rows 3, rows removed 5, 1 shared buffer hit, 0.234 ms planning time, and 0.056 ms execution time.

## Incorrect order on 1,000,008 rows

With `idx_salary_department` on `(salary, department)`, the buffer-enabled query plan was:

```text
Gather  (cost=1000.00..17625.45 rows=654 width=50) (actual time=0.631..144.696 rows=702.00 loops=1)
  Workers Planned: 2
  Workers Launched: 2
  Buffers: shared hit=10310
  ->  Parallel Seq Scan on employees  (cost=0.00..16560.05 rows=272 width=50) (actual time=0.685..77.333 rows=234.00 loops=3)
        Filter: ((salary > '50000'::numeric) AND ((department)::text = 'Sales'::text))
        Rows Removed by Filter: 333102
        Buffers: shared hit=10310
Planning:
  Buffers: shared hit=107 read=1
Planning Time: 4.649 ms
Execution Time: 144.886 ms
```

The `Parallel Seq Scan` visited the 1,000,008 rows; the filter removed 333,102 rows per loop over three loops (999,306 total) and returned 234 rows per loop (702 total). The incorrect-order index was not used for this query in this plan.

## Corrected order on the same dataset

With `idx_department_salary` on `(department, salary)`, the buffer-enabled query plan was:

```text
Index Scan using idx_department_salary on employees  (cost=0.42..2288.87 rows=931 width=50) (actual time=0.145..2.347 rows=702.00 loops=1)
  Index Cond: (((department)::text = 'Sales'::text) AND (salary > '50000'::numeric))
  Index Searches: 1
  Buffers: shared hit=702 read=5
Planning:
  Buffers: shared hit=107 read=1
Planning Time: 2.672 ms
Execution Time: 2.397 ms
```

## Comparison and result equivalence

| Test state | Actual plan | Returned rows | Planning time | Execution time |
|---|---|---:|---:|---:|
| Original 8-row sample; starter index | `Seq Scan` | 2 for Sales; 3 for Engineering | 5.003 ms for first `EXPLAIN ANALYZE` | 0.151 ms for first query |
| 1,000,008 rows; `(salary, department)` | `Parallel Seq Scan` | 702 | 4.649 ms | 144.886 ms |
| 1,000,008 rows; `(department, salary)` | `Index Scan` | 702 | 2.672 ms | 2.397 ms |

The performance script also captured a result set under each index state. PostgreSQL reported 702 rows from each and `differing_rows = 0`. Therefore the index change altered the measured plan, not the query's results.

Timings and buffer counts above are actual values from the recorded run, not expected values. Re-running can yield different timings because of cache state, machine load, statistics, data distribution, and PostgreSQL version. The original eight-row scans and the generated-data comparison should not be treated as a general benchmark.
