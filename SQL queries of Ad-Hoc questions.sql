SELECT * FROM dim_customer;
SELECT * FROM dim_product;
SELECT * FROM fact_gross_price;
SELECT * FROM fact_manufacturing_cost;
SELECT * FROM fact_pre_invoice_deductions;
SELECT * FROM fact_sales_monthly ;

/* EDA of all the tables */
/* Exploring dim_customer */
SELECT COUNT(customer_code) FROM dim_customer;
SELECT DISTINCT CUSTOMER FROM dim_customer; SELECT DISTINCT PLATFORM FROM dim_customer;
SELECT DISTINCT CHANNEL FROM dim_customer; SELECT DISTINCT MARKET FROM dim_customer;
SELECT DISTINCT SUB_ZONE FROM dim_customer; SELECT DISTINCT region FROM dim_customer;
/* cleaning dim_customer table */
UPDATE dim_customer 
SET MARKET = 'Philippines' 
WHERE Market = 'Philiphines' ;

UPDATE dim_customer 
SET MARKET = 'New Zealand' 
WHERE Market = 'Newzealand' ;

/* exploring product table */
select count(*) from dim_product; select count(distinct product_code) from dim_product; 
select count(distinct product) from dim_product;
/* it means all product codes are unique and distinct and same product can have multiple product_code, product_code
 is unique for each row depending on other fields as well */
SELECT * FROM dim_customer WHERE region="NA" ;

select distinct category from dim_product;
select distinct variant from dim_product;

/*joining gross_price and manufacturing_cost table under a new table */
CREATE TABLE fact_costs AS
SELECT 
F.product_code as product_code,F.fiscal_year AS fiscal_year, F.gross_price as gross_price, 
M.manufacturing_cost as manufacturing_cost
FROM fact_gross_price F INNER JOIN fact_manufacturing_cost M 
ON F.product_code = M.product_code AND F.fiscal_year = M.cost_year;

/*Making product_code anf fiscal_year primary key of fact_costs */
ALTER TABLE fact_costs
ADD PRIMARY KEY ( PRODUCT_CODE, FISCAL_YEAR) ;


/*creating a new table fact_sales from fact_sales_monthly and adding the pre_invoice_deduction to fact_sales */
CREATE TABLE fact_sales AS
SELECT  fs.*, fd.pre_invoice_discount_pct
FROM fact_sales_monthly fs join fact_pre_invoice_deductions fd 
ON fs.customer_code = fd.customer_code and fs.fiscal_year = fd.fiscal_year ;

SELECT * FROM dim_customer;
SELECT * FROM dim_product;
SELECT * FROM fact_pre_invoice_deductions;
SELECT * FROM fact_sales_monthly ;
select * from fact_costs;
SELECT * FROM fact_sales;


/*Calculating column in fact_sales table. For Atliq, FY starts in Sept and ends in Aug. */ 
alter table fact_sales add column date_for_qtr date;
update fact_sales set date_for_qtr = date_add(`date`, interval 4 MONTH);
alter table fact_sales add column `quarter` varchar(4) ;
update fact_sales 
set `quarter` = concat("Q",quarter(date_for_qtr));
select * from fact_sales;

/*Now considering the tables, deduction, gross price, manufacturing cost data are collected in the new tables */
SELECT * FROM dim_customer;
SELECT * FROM dim_product;
select * from fact_sales;
select * from fact_costs;

/*Ad-Hoc Question 1:  Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region. */
SELECT market
FROM dim_customer WHERE customer="Atliq Exclusive" AND region="APAC";


/*Ad-Hoc Question 2: What is the percentage of unique product increase in 2021 vs. 2020?
 The final output contains these fields, unique_products_2020 unique_products_2021 percentage_chg */
with unique_count as ( 
select 
case when fiscal_year=2020 then count(distinct p.product_code) end as unique_product_2020, 
case when fiscal_year=2021 then count(distinct p.product_code) end as unique_product_2021 
from dim_product p join fact_sales s on p.product_code = s.product_code 
group by s.fiscal_year 
) 
select 
sum(unique_product_2020) as unique_product_2020, 
sum(unique_product_2021) as unique_product_2021, 
round( 100*(sum(unique_product_2021)-sum(unique_product_2020))/sum(unique_product_2020) , 2 ) 
as percentage_chg from unique_count;
 
/*Ad-Hoc Question 3: Provide a report with all the unique product counts 
for each segment and sort them in descending order of product counts. The final output contains 2 fields, segment, product_count */
select segment, count(distinct product_code) as product_count
from dim_product group by segment
order by 2 desc;

/*Ad-Hoc Question 4: Follow-up: Which segment had the most increase in unique products in 2021 vs 2020? 
The final output contains these fields: segment, product_count_2020, product_count_2021, difference */
with cte as (
select fs.fiscal_year,dp.segment, 
coalesce(
case when fs.fiscal_year=2020 then count(distinct dp.product_code) end,
case when fs.fiscal_year=2021 then count(distinct dp.product_code) end )as product_count
from dim_product dp join fact_sales fs on dp.product_code=fs.product_code
group by fs.fiscal_year, dp.segment
),
cte2 as (
select segment, 
sum(case when fiscal_year=2020 then product_count end) as product_count_2020,
sum(case when fiscal_year=2021 then product_count end) as product_count_2021
from cte group by segment
)
select segment, product_count_2020, product_count_2021, (product_count_2021 - product_count_2020) as difference
from cte2 order by difference desc;



/*Ad-Hoc Question 5: Get the products that have the highest and lowest manufacturing costs. 
The final output should contain these fields: product_code, product, manufacturing_cost */
select * from fact_costs;
select * from dim_product;

with max_manu_cost as (
select p.product_code, product, MAX(manufacturing_cost) as Highest_Lowest_Manufacturing_Cost
from dim_product p inner join fact_costs c on p.product_code = c.product_code
group by 1,2 order by 3 desc limit 1
),
min_manu_cost as( 
select p.product_code, product, MIN(manufacturing_cost) as Highest_Lowest_Manufacturing_Cost
from dim_product p inner join fact_costs c on p.product_code = c.product_code
 group by 1,2 order by 3 asc limit 1
)
select * from max_manu_cost 
union 
select * from min_manu_cost ;


/*Ad-Hoc Question 6: Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct
for the fiscal year 2021 and in the Indian market. The final output contains these fields:
customer_code, customer, average_discount_percentage */
select c.customer_code, c.customer, round(100*avg(pre_invoice_discount_pct),2) as average_discount_percentage
from dim_customer c inner join fact_sales f on c.customer_code = f.customer_code 
where f.fiscal_year=2021 and c.market="India"
group by c.customer_code, c.customer
order by average_discount_percentage desc limit 5;

/*Ad-Hoc Question 7: Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month . 
This analysis helps to get an idea of low and high-performing months and take strategic decisions.
The final report contains these columns: Month, Year, Gross sales Amount */
select monthname(s.date) as month, year(s.date) as year, cu.customer, 
round(sum(s.sold_quantity * co.gross_price),2) as gross_sales_amount
from dim_customer cu join fact_sales s on cu.customer_code = s.customer_code
join fact_costs co on s.product_code=co.product_code
where cu.customer="Atliq Exclusive" 
group by month, year, cu.customer;
 
 
 /*Ad-Hoc Question 8: In which quarter of 2020, got the maximum total_sold_quantity? 
 The final output contains these fields sorted by the total_sold_quantity, Quarter total_sold_quantity */
select quarter, SUM(sold_quantity) as total_sold_quantity
from fact_sales group by 1
order by total_sold_quantity desc;
 
 
/*Ad-Hoc Question 9: Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution? 
The final output contains these fields: channel, gross_sales_mln percentage */

with sales_mln as (
select c.channel, round( SUM(s.sold_quantity * co.gross_price)/1000000, 2) as gross_sales_mln
from 
dim_customer c join fact_sales s on c.customer_code = s.customer_code 
join fact_costs co on s.product_code = co.product_code
group by 1
)
select channel,concat( round(100*gross_sales_mln/(select sum(gross_sales_mln) from sales_mln) ,2), "%") as gross_sales_pct
from sales_mln 
order by gross_sales_pct;

select * from fact_costs;
select * from fact_sales;

 /*Ad-Hoc Question 10: Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021? 
The final output contains these fields: division, product_code, product, total_sold_quantity, rank_order */
select * from dim_product;
select * from fact_sales;
with qty_cte as (
select p.division, p.product_code, p.product, sum(s.sold_quantity) as total_sold_quantity
from dim_product p join fact_sales s on p.product_code = s.product_code
where s.fiscal_year=2021
group by 1,2,3 ),
rnk_cte as(
select *, dense_rank() over ( partition by division order by total_sold_quantity desc)  as rank_order
from qty_cte 
)
select * from rnk_cte where rank_order >=1 and rank_order <= 3 ;




