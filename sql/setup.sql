\set ON_ERROR_STOP on

DROP TABLE IF EXISTS employees;

CREATE TABLE employees (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    department VARCHAR(50),
    salary NUMERIC,
    hire_date DATE
);

CREATE INDEX idx_salary_department ON employees(salary, department);

\ir ../db/sample_data.sql

ANALYZE employees;
