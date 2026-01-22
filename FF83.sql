--https://frostyfriday.org/blog/2024/03/01/week-83-basic/

--sales_dataというテーブルから情報を抽出するSnowflakeのクエリを最適化するタスクがあります。sales_data テーブルには、product_id、quantity_sold、価格、transaction_dateなどの列を含む販売トランザクションに関する情報が含まれています。
--あなたの目標は?総収益が最も高い上位 10 個の商品を取得し、合計収益は各トランザクションのquantity_soldと価格の積の合計として計算されます。
--ヒント: SELECT ステートメントでは、QUALIFY句によってウィンドウ関数の結果がフィルター処理されます。
--↓↓↓↓↓↓↓↓↓↓↓↓↓--
--つまり、「売れた数×金額が多いPRODUCT_IDの上位10個を出せ」ということを問われている

use database test_db;
use schema test_schema;
use warehouse COMPUTE_WH;
use role ACCOUNTADMIN;

--↓お題として提供されたSQL文↓
-- Create sales_data table
CREATE or REPLACE TABLE sales_data (
  product_id INT,
  quantity_sold INT,
  price DECIMAL(10,2),
  transaction_date DATE
);

-- Insert sample values
INSERT INTO sales_data (product_id, quantity_sold, price, transaction_date)
VALUES
  (1, 10, 15.99, '2024-02-01'),
  (1, 8, 15.99, '2024-02-05'),
  (2, 15, 22.50, '2024-02-02'),
  (2, 20, 22.50, '2024-02-07'),
  (3, 12, 10.75, '2024-02-03'),
  (3, 18, 10.75, '2024-02-08'),
  (4, 5, 30.25, '2024-02-04'),
  (4, 10, 30.25, '2024-02-09'),
  (5, 25, 18.50, '2024-02-06'),
  (5, 30, 18.50, '2024-02-10');
--↑お題として提供されたSQL文↑

--INSERTしたデータを見てみる
TABLE sales_data ORDER BY product_id;

--QUALIFYとセットで使うWindow関数についての説明。
--別シート：WindowFunction.sql


--今回のケースではROW_NUMBER()、RANK()、DENSE_RANK()どれを使っても同じ結果です。（同額のデータが存在しないため）
--Window関数：RANK()を使用していきます。

--ORDER BY + LIMIT（8行）
SELECT 
  product_id,
  SUM(quantity_sold * price) AS total_revenue,
  RANK() OVER (ORDER BY total_revenue DESC) AS ranking
FROM sales_data
GROUP BY product_id
ORDER BY total_revenue DESC
LIMIT 10;


--サブクエリ（9行）
SELECT * FROM (
  SELECT 
      product_id, 
      SUM(quantity_sold * price) AS total_revenue,
      RANK() OVER (ORDER BY total_revenue DESC) AS ranking
  FROM sales_data
  GROUP BY product_id
) WHERE ranking <= 10
ORDER BY total_revenue DESC;


--CTE（Common Table Expression：共通テーブル式）（15行）
WITH product_sales AS (
  SELECT 
    product_id,
    SUM(quantity_sold * price) AS total_revenue,
    RANK() OVER (ORDER BY total_revenue DESC) AS ranking
  FROM sales_data
  GROUP BY product_id
)
SELECT 
  product_id,
  total_revenue,
  ranking
FROM product_sales
WHERE ranking <= 10
ORDER BY total_revenue DESC;
--サブクエリより長くなるが、上から読んでいける可読性の良さ


--qualifyを使ったSQL（8行）
SELECT
  product_id,
  SUM(quantity_sold * price) AS total_revenue,
  RANK() OVER (ORDER BY total_revenue DESC) AS ranking
FROM
  sales_data
GROUP BY product_id
QUALIFY ranking <= 10;


--エラーになるクエリ（where句にWindow関数の結果を使う）
SELECT 
  product_id,
  SUM(quantity_sold * price) AS total_revenue,
  RANK() OVER (ORDER BY total_revenue DESC) AS ranking
FROM sales_data
WHERE RANK() OVER (ORDER BY total_revenue DESC) <= 10
GROUP BY product_id
ORDER BY total_revenue DESC;
--where句にWindow関数の結果を使うのはNG、qualifyならWindow関数の結果に対してフィルタ可能

--公式ドキュメント
--https://docs.snowflake.com/ja/sql-reference/constructs/qualify
--クエリの実行順序（の抜粋）
--Where
--Window
--QUALIFY
--Where句にWindow関数が使えないのは実行順序によるもの。
--先にWhere句が走るが、そのWhere句の中でWindow関数を使おうとしてもまだWindow関数が実行されていないためエラーになる
--Qualify句の場合はWindow関数の方が先に走っているのでエラーにならない



--ところで・・・。
--上位10個という問題なんだけど、5つしかproduct_idがないのでコレでいいのかどうか、よくわからない
--上位10個を満たすためにテストデータを増やす（100件にする）


--最近発見した便利機能
--テーブル定義だけコピってテーブル作成：sales_data_100
CREATE OR REPLACE TABLE sales_data_100 LIKE sales_data;
DESC TABLE sales_data_100;
SELECT count(*) FROM sales_data_100;

INSERT INTO sales_data_100 (product_id, quantity_sold, price, transaction_date) VALUES
--お題で指定されている10件
(1, 10, 15.99, '2024-02-01'),
(1, 8, 15.99, '2024-02-05'),
(2, 15, 22.50, '2024-02-02'),
(2, 20, 22.50, '2024-02-07'),
(3, 12, 10.75, '2024-02-03'),
(3, 18, 10.75, '2024-02-08'),
(4, 5, 30.25, '2024-02-04'),
(4, 10, 30.25, '2024-02-09'),
(5, 25, 18.50, '2024-02-06'),
(5, 30, 18.50, '2024-02-10'),

-- Product ID 1 (3 records)
(1, 15, 15.99, '2024-02-12'),
(1, 12, 15.99, '2024-02-15'),
(1, 8, 15.99, '2024-02-28'),

-- Product ID 2 (5 records)
(2, 16, 22.50, '2024-02-08'),
(2, 18, 22.50, '2024-02-10'),
(2, 20, 22.50, '2024-02-20'),
(2, 22, 22.50, '2024-02-25'),
(2, 11, 22.50, '2024-02-26'),

-- Product ID 3 (3 records)
(3, 14, 10.75, '2024-02-02'),
(3, 19, 10.75, '2024-02-12'),
(3, 11, 10.75, '2024-02-18'),

-- Product ID 4 (5 records)
(4, 7, 30.25, '2024-02-08'),
(4, 12, 30.25, '2024-02-05'),
(4, 6, 30.25, '2024-02-15'),
(4, 9, 30.25, '2024-02-22'),
(4, 10, 30.25, '2024-02-28'),

-- Product ID 5 (4 records)
(5, 32, 18.50, '2024-02-01'),
(5, 25, 18.50, '2024-02-14'),
(5, 28, 18.50, '2024-02-18'),
(5, 21, 18.50, '2024-02-25'),

-- Product ID 6 (2 records)
(6, 38, 12.99, '2024-02-10'),
(6, 45, 12.99, '2024-02-20'),

-- Product ID 7 (3 records)
(7, 12, 45.75, '2024-02-07'),
(7, 8, 45.75, '2024-02-14'),
(7, 6, 45.75, '2024-02-22'),

-- Product ID 8 (5 records)
(8, 18, 8.25, '2024-02-09'),
(8, 15, 8.25, '2024-02-11'),
(8, 22, 8.25, '2024-02-16'),
(8, 20, 8.25, '2024-02-26'),
(8, 27, 8.25, '2024-02-27'),

-- Product ID 9 (4 records)
(9, 40, 5.80, '2024-02-11'),
(9, 35, 5.80, '2024-02-16'),
(9, 33, 5.80, '2024-02-24'),
(9, 28, 5.80, '2024-02-27'),

-- Product ID 10 (2 records)
(10, 5, 89.99, '2024-02-09'),
(10, 3, 89.99, '2024-02-13'),

-- Product ID 11 (4 records)
(11, 21, 14.50, '2024-02-06'),
(11, 24, 14.50, '2024-02-13'),
(11, 29, 14.50, '2024-02-19'),
(11, 27, 14.50, '2024-02-28'),

-- Product ID 12 (3 records)
(12, 19, 33.25, '2024-02-04'),
(12, 16, 33.25, '2024-02-17'),
(12, 14, 33.25, '2024-02-21'),

-- Product ID 13 (5 records)
(13, 15, 7.99, '2024-02-03'),
(13, 9, 7.99, '2024-02-09'),
(13, 11, 7.99, '2024-02-17'),
(13, 12, 7.99, '2024-02-23'),
(13, 8, 7.99, '2024-02-26'),

-- Product ID 14 (2 records)
(14, 38, 19.75, '2024-02-12'),
(14, 42, 19.75, '2024-02-21'),

-- Product ID 15 (4 records)
(15, 4, 55.50, '2024-02-08'),
(15, 6, 55.50, '2024-02-12'),
(15, 7, 55.50, '2024-02-23'),
(15, 8, 55.50, '2024-02-27'),

-- Product ID 16 (3 records)
(16, 17, 11.25, '2024-02-01'),
(16, 13, 11.25, '2024-02-15'),
(16, 14, 11.25, '2024-02-18'),

-- Product ID 17 (5 records)
(17, 13, 28.90, '2024-02-05'),
(17, 16, 28.90, '2024-02-10'),
(17, 19, 28.90, '2024-02-16'),
(17, 11, 28.90, '2024-02-24'),
(17, 17, 28.90, '2024-02-29'),

-- Product ID 18 (2 records)
(18, 11, 42.00, '2024-02-14'),
(18, 8, 42.00, '2024-02-18'),

-- Product ID 19 (4 records)
(19, 25, 16.75, '2024-02-07'),
(19, 22, 16.75, '2024-02-11'),
(19, 20, 16.75, '2024-02-20'),
(19, 18, 16.75, '2024-02-25'),

-- Product ID 20 (3 records)
(20, 15, 37.80, '2024-02-02'),
(20, 12, 37.80, '2024-02-16'),
(20, 10, 37.80, '2024-02-19'),

-- Product ID 21 (5 records)
(21, 35, 9.50, '2024-02-04'),
(21, 33, 9.50, '2024-02-08'),
(21, 31, 9.50, '2024-02-15'),
(21, 28, 9.50, '2024-02-22'),
(21, 37, 9.50, '2024-02-28'),

-- Product ID 22 (2 records)
(22, 5, 67.25, '2024-02-11'),
(22, 7, 67.25, '2024-02-20'),

-- Product ID 23 (4 records)
(23, 16, 21.99, '2024-02-09'),
(23, 19, 21.99, '2024-02-13'),
(23, 22, 21.99, '2024-02-22'),
(23, 24, 21.99, '2024-02-28'),

-- Product ID 24 (3 records)
(24, 18, 13.75, '2024-02-03'),
(24, 14, 13.75, '2024-02-17'),
(24, 12, 13.75, '2024-02-19'),

-- Product ID 25 (5 records)
(25, 6, 24.50, '2024-02-06'),
(25, 11, 24.50, '2024-02-09'),
(25, 8, 24.50, '2024-02-18'),
(25, 1, 24.50, '2024-02-23'),
(25, 15, 24.50, '2024-02-27');

--INSERTしたデータを見てみる
TABLE sales_data_100 ORDER BY product_id;

--上位10件に絞らずにtotal_revenueの多い順product_idで出力
SELECT 
  product_id, 
  SUM(quantity_sold * price) AS total_revenue,
  RANK() OVER (ORDER BY total_revenue DESC) AS ranking
FROM sales_data_100
GROUP BY product_id
ORDER BY total_revenue DESC;

--ORDER BY + LIMIT
SELECT 
  product_id,
  SUM(quantity_sold * price) AS total_revenue,
  RANK() OVER (ORDER BY total_revenue DESC) AS ranking
FROM sales_data_100
GROUP BY product_id
ORDER BY total_revenue DESC
LIMIT 10;


--サブクエリ
SELECT * FROM (
  SELECT 
      product_id, 
      SUM(quantity_sold * price) AS total_revenue,
      RANK() OVER (ORDER BY total_revenue DESC) AS ranking
  FROM sales_data_100
  GROUP BY product_id
) WHERE ranking <= 10
ORDER BY total_revenue DESC;

--CTE（共通テーブル式）
WITH product_sales AS (
  SELECT 
    product_id,
    SUM(quantity_sold * price) AS total_revenue,
    RANK() OVER (ORDER BY total_revenue DESC) AS ranking
  FROM sales_data_100
  GROUP BY product_id
)
SELECT 
  product_id,
  total_revenue,
  ranking
FROM product_sales
WHERE ranking <= 10
ORDER BY total_revenue DESC;


--qualify
SELECT
  product_id,
  SUM(quantity_sold * price) AS total_revenue,
  RANK() OVER (ORDER BY total_revenue DESC) AS ranking
FROM
  sales_data_100
GROUP BY product_id
qualify ranking <= 10;







--もっと複雑なケース（LIMITではできないケース）
--product_idでまとめた順位を出しつつ、さらにproduct_idごとに上位3件をの取引日を表示する
--QUALIFY
WITH base_data AS (
    SELECT 
        product_id,
        transaction_date,
        quantity_sold,
        price,
        quantity_sold * price AS transaction_revenue,
        SUM(quantity_sold * price) OVER (PARTITION BY product_id) AS product_total_revenue
    FROM sales_data_100
),
ranked_products AS (
    SELECT 
        product_id,
        product_total_revenue,
        RANK() OVER (ORDER BY product_total_revenue DESC) AS product_rank
    FROM base_data
    GROUP BY product_id, product_total_revenue
)
SELECT 
    b.product_id,
    r.product_total_revenue,
    r.product_rank,
    b.transaction_date,
    b.quantity_sold,
    b.price,
    b.transaction_revenue,
    RANK() OVER (PARTITION BY b.product_id ORDER BY b.transaction_revenue DESC) AS transaction_rank
FROM base_data b
JOIN ranked_products r ON b.product_id = r.product_id
WHERE r.product_rank <= 10
QUALIFY RANK() OVER (PARTITION BY b.product_id ORDER BY b.transaction_revenue DESC) <= 3
ORDER BY r.product_rank, b.product_id, transaction_rank;


--Qualifyを使わない
WITH product_total AS (
    -- 製品ごとの総売上
    SELECT 
        product_id,
        SUM(quantity_sold * price) AS total_revenue
    FROM sales_data_100
    GROUP BY product_id
),
product_with_rank AS (
    -- 全製品にランキングを付与
    SELECT 
        product_id,
        total_revenue,
        RANK() OVER (ORDER BY total_revenue DESC) AS product_rank
    FROM product_total
),
top_10_products AS (
    -- 上位10製品を抽出（QUALIFYの代わりにWHERE）
    SELECT 
        product_id,
        total_revenue,
        product_rank
    FROM product_with_rank
    WHERE product_rank <= 10
),
transaction_with_rank AS (
    -- 各製品内での取引ランキング
    SELECT 
        s.product_id,
        s.transaction_date,
        s.quantity_sold,
        s.price,
        s.quantity_sold * s.price AS transaction_revenue,
        RANK() OVER (PARTITION BY s.product_id ORDER BY s.quantity_sold * s.price DESC) AS transaction_rank
    FROM sales_data_100 s
    WHERE s.product_id IN (SELECT product_id FROM top_10_products)
)
SELECT 
    t.product_id,
    p.total_revenue AS product_total_revenue,
    p.product_rank,
    t.transaction_date,
    t.quantity_sold,
    t.price,
    t.transaction_revenue,
    t.transaction_rank
FROM transaction_with_rank t
JOIN top_10_products p ON t.product_id = p.product_id
WHERE t.transaction_rank <= 3
ORDER BY p.product_rank, t.product_id, t.transaction_rank;
