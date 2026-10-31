\set ON_ERROR_STOP on

DROP INDEX IF EXISTS idx_department_salary;
DROP INDEX IF EXISTS idx_salary_department;
CREATE INDEX idx_salary_department ON employees(salary, department);

ANALYZE employees;
