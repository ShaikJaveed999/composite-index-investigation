\set ON_ERROR_STOP on
\timing on

TRUNCATE employees RESTART IDENTITY;

\ir ../db/sample_data.sql

INSERT INTO employees (name, department, salary, hire_date)
SELECT
    'Synthetic employee ' || employee_number,
    CASE
        WHEN employee_number % 1000 = 0 THEN 'Sales'
        WHEN employee_number % 10 = 0 THEN 'Engineering'
        ELSE 'Operations'
    END,
    (30000 + employee_number % 70001)::NUMERIC,
    DATE '2015-01-01' + (employee_number % 3650)
FROM generate_series(1, 1000000) AS employee_number;

ANALYZE employees;

\echo 'Plan with the starter project index order: (salary, department)'
\ir incorrect_index.sql

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

CREATE TEMP TABLE incorrect_index_results AS
SELECT *
FROM employees
WHERE department = 'Sales'
AND salary > 50000;

\echo 'Plan with the corrected index order: (department, salary)'
\ir corrected_index.sql

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

CREATE TEMP TABLE corrected_index_results AS
SELECT *
FROM employees
WHERE department = 'Sales'
AND salary > 50000;

SELECT
    (SELECT COUNT(*) FROM incorrect_index_results) AS incorrect_index_rows,
    (SELECT COUNT(*) FROM corrected_index_results) AS corrected_index_rows;

SELECT COUNT(*) AS differing_rows
FROM (
    (SELECT * FROM incorrect_index_results
     EXCEPT
     SELECT * FROM corrected_index_results)
    UNION ALL
    (SELECT * FROM corrected_index_results
     EXCEPT
     SELECT * FROM incorrect_index_results)
) AS differences;
