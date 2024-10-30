use role sysadmin;
use warehouse compute_wh;
create database frostyfriday;
create schema week39;

--https://frostyfriday.org/blog/2023/03/24/week-39-basic/  start
create or replace table customer_deets (
    id int,
    name string,
    email string
);

insert into customer_deets values
    (1, 'Jeff Jeffy', 'jeff.jeffy121@gmail.com'),
    (2, 'Kyle Knight', 'kyleisdabest@hotmail.com'),
    (3, 'Spring Hall', 'hall.yay@gmail.com'),
    (4, 'Dr Holly Ray', 'drdr@yahoo.com');
--https://frostyfriday.org/blog/2023/03/24/week-39-basic/  end

--my code start
CREATE OR REPLACE MASKING POLICY email_mask_policy AS (val string) RETURNS string ->
  CASE
    WHEN current_role() IN ('ACCOUNTADMIN') THEN val
    ELSE REGEXP_REPLACE(val, '^[^@]+', '******')
  END;

ALTER TABLE customer_deets ALTER COLUMN email SET MASKING POLICY email_mask_policy;
--sysadmin
select * from customer_deets;

--accountadmin
use role accountadmin;
select * from customer_deets;
--my code end
