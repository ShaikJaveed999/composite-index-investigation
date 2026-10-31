\set ON_ERROR_STOP on

DROP INDEX IF EXISTS idx_salary_department;
DROP INDEX IF EXISTS idx_department_salary;
CREATE INDEX idx_department_salary ON employees(department, salary);

ANALYZE employees;
