\set ON_ERROR_STOP on

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

SELECT *
FROM employees
WHERE department = 'Sales'
AND salary > 50000;

EXPLAIN ANALYZE
SELECT *
FROM employees
WHERE department = 'Engineering'
AND salary >= 70000;

EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM employees
WHERE department = 'Engineering'
AND salary >= 70000;

SELECT *
FROM employees
WHERE department = 'Engineering'
AND salary >= 70000;
