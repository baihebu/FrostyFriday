--今回の前提となるWindow関数について

use database test_db;
use schema test_schema;
use warehouse COMPUTE_WH;
use role ACCOUNTADMIN;

CREATE OR REPLACE TABLE employees (
  employee_id INT,
  employee_name VARCHAR(50),
  department VARCHAR(50),
  salary INT
);

INSERT INTO employees (employee_id, employee_name, department, salary) VALUES
(1, '佐藤', '営業部', 800),
(2, '鈴木', '営業部', 650),   --サラリーが同じ
(3, '田中', '営業部', 650),   --サラリーが同じ
(4, '高橋', '営業部', 600),
(5, '伊藤', '開発部', 600),
(6, '渡辺', '開発部', 900),
(7, '山本', '開発部', 500),
(8, '中村', '開発部', 700),
(9, '小林', '開発部', 800);

TABLE employees;

--Window関数のROW_NUMBER()、RANK()、DENSE_RANK()をまとめて出力
SELECT
  employee_name,
  department,
  salary,
  ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC) AS row_number,
  RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS rank,
  DENSE_RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS dense_rank
FROM employees
ORDER BY department, salary DESC;

--お掃除
DROP TABLE employees;
