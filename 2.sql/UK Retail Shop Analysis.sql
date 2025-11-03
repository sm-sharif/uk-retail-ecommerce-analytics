create table customers (
customer_id integer primary key, 
country varchar(100),
first_purchase_date timestamp
);

create table invoices (
invoice_no varchar(50) primary key,
customer_id integer references customers (customer_id),
invoice_date timestamp,
country varchar(100),
total_amount decimal (10,2)
);

create table products (
stock_code varchar(50) primary key,
product_name varchar(255),
category varchar(100)
);

create table invoice_items (
line_item_id integer primary key,
invoice_no varchar(50) references invoices(invoice_no),
stock_code varchar(50),
quantity integer,
unit_price decimal (10,2)
);



SELECT 'customers' as table_name, COUNT(*) as rows FROM customers
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'invoices', COUNT(*) FROM invoices
UNION ALL
SELECT 'invoice_items', COUNT(*) FROM invoice_items;





-- Query 1: Business Overview KPIs
-- Question: What are the key business metrics (total revenue, total orders, total customers, average order value)?

select
sum(total_amount) as total_revenue,
count(distinct invoice_no) as total_orders,
count(distinct customer_id) as total_customers,
round(avg(total_amount),2) avg_order_value
from invoices

-- Query 2: Monthly Revenue Trend
-- Question: How is revenue trending month-over-month?

select
    date_trunc('month', invoice_date) as month_year,
    sum(total_amount) as total_revenue
from invoices
group by date_trunc('month', invoice_date)
order by month_year;


-- Query 3: Top 10 Products by Revenue
-- Question: Which products generate the most revenue?

select product_name,
sum(unit_price * quantity) total_revenue
from products p
join invoice_items i
on p.stock_code = i.stock_code
group by product_name
order by total_revenue desc
limit 10 

-- Query 4: Top 10 Products by Quantity
-- Question: Which products sell the most units?

select product_name,
sum(quantity) total_quantity
from products p
join invoice_items i
on p.stock_code = i.stock_code
group by product_name
order by total_quantity desc
limit 10 


-- Question 4b: Top 10 worst-selling products (by quantity)

select product_name,
sum(quantity) total_quantity,
sum(unit_price * quantity) total_revenue
from products p
join invoice_items i
on p.stock_code = i.stock_code
group by product_name
having sum(unit_price * quantity) >0
order by total_quantity asc
limit 10 

-- Query 5: Category Performance
-- Question: How much revenue does each product category generate?

select category,
sum(quantity) total_quantity,	
sum(unit_price * quantity) total_revenue
from products p
join invoice_items i
on p.stock_code = i.stock_code
group by category
order by total_revenue desc
limit 10 

-- Query 6: Best and Worst Performing Products
-- Question: Which products have the highest and lowest sales?

with cte as(
select
product_name,
sum(unit_price*quantity) as total_sales
from products p
join invoice_items inv
on p.stock_code = inv.stock_code
group by product_name
having sum(unit_price*quantity)>0
),

ranked as(
select product_name,
total_sales,
max(total_sales) over() as highest_month,
min(total_sales) over() as lowest_month
from cte
)
select 
product_name,
total_sales
from ranked
where total_sales = highest_month
or total_sales = lowest_month



-- Query 7: Price Range by Category
-- Question: What is the price range (min, max, average) in each category?

select 
category,
max(unit_price) max_price,
min(unit_price) min_price,
round(avg(unit_price),2) avg_price
from products p
join invoice_items i
on p.stock_code = i.stock_code
and i.unit_price > 0
group by category

-- Query 8: Sales by Country
-- Question: Which countries generate the most revenue and have the most customers?

select 
country,
sum(total_amount) as total_revenue,
count(distinct customer_id) as customers
from invoices
group by country
order by total_revenue desc, customers desc


-- Query 9: Top 10 Customers by Spend
-- Question: Who are our biggest spenders?

select 
customer_id,
sum(total_amount) as total_spend
from invoices
group by customer_id
order by total_spend desc
limit 10

-- Query 10: New Customers per Month
-- Question: How many new customers are joining each month?
select 
extract (year from first_purchase_date) as year,
extract (month from first_purchase_date) as month,
count(customer_id) as new_customers
from customers
group by extract (year from first_purchase_date),extract (month from first_purchase_date)
order by year, month


-- Query 11: Top Category per Country
-- Question: What is the best-selling category in each country?
with cte as(
select 
i.country as country,
p.category as category,
sum(i.total_amount) as total_revenue
from products p
join invoice_items inv
on p.stock_code = inv.stock_code
join invoices i
on i.invoice_no = inv.invoice_no
group by i.country,p.category
),

ranked as(
select
country, 
category,
total_revenue,
row_number() over(partition by country order by total_revenue desc) as ranking
from cte
)

select 
country,
category,
total_revenue
from ranked 
where ranking = 1
order by total_revenue desc


-- Query 12: Monthly Sales Comparison
-- Question: Which months had the highest and lowest sales?
with cte as(
select 
date_trunc ('month', invoice_date) as months,
sum(total_amount) as total_sales
from invoices
group by date_trunc ('month', invoice_date)
having sum(total_amount)>0
),
ranked as(
select months,
total_sales,
max(total_sales) over() as highest_sale,
min(total_sales) over() as lowest_sale
from cte
)

select 
months,
total_sales
from ranked
where total_sales = highest_sale
or total_sales = lowest_sale
	
-- Query 13: RFM Customer Segmentation
-- Question: How can we segment customers by Recency, Frequency, and Monetary value?

with reference as (
select
max(invoice_date) as max_date
from invoices
),
rfm as(
select 
customer_id,
max(invoice_date) as last_purchase_date,
count(distinct invoice_no) as purchase_frequency,
sum(total_amount) as total_monetary,
(select max_date from reference) - max(invoice_date) as recent_days
from invoices
group by customer_id
),

rfm_score as(
select 
customer_id,
last_purchase_date,
purchase_frequency,
total_monetary,
recent_days,
6-ntile(5) over(order by recent_days asc) as r_score,
6-ntile(5) over(order by total_monetary desc) as m_score,
6-ntile(5) over(order by purchase_frequency desc) as f_score
from rfm
)

select
customer_id,
last_purchase_date,
purchase_frequency,
total_monetary,
recent_days,
r_score,
m_score,
f_score,
concat(r_score,m_score,f_score) as rfm_segment,
case
when r_score>=4 and m_score>=4 and f_score>=4 then 'Champions'
when r_score>=4 and f_score>=3 then 'Loyal Customer'
when r_score>=3 and f_score <=2 and m_score<=2 then 'At Risk'
when r_score <=2 and f_score <=2 and m_score <=2 then 'Lost'
when r_score >=4 and f_score <=2 then 'New Customers'
else 'Regular'
end as customer_segment
from rfm_score
order by r_score desc, m_score desc, f_score desc


-- Query 14: Churn Analysis
-- Question: Which customers are inactive (haven’t purchased in 90+ days)?

with reference as(
select max(invoice_date) as max_date
from invoices 
),
churn as(
select
customer_id,
country,
max(invoice_date) as last_purchase,
count(distinct invoice_no) as total_orders,
sum(total_amount) as lifetime_value,
extract(day from (select max_date from reference) - max(invoice_date)) as days_since_last_purchase
from invoices 
group by customer_id, country
)
select 
customer_id,
country,
last_purchase,
total_orders,
lifetime_value,
days_since_last_purchase,
round(lifetime_value/total_orders,2) as avg_order_value,
case
when days_since_last_purchase >= 180 then 'Churned'
when days_since_last_purchase >= 90 then 'At Risk'
when days_since_last_purchase >= 60 then 'Needs Attention'
else 'Active'
end as churn_status
from churn
where days_since_last_purchase >=60
order by days_since_last_purchase desc, lifetime_value desc


-- Churn Summary Statistics

with churn as(
select 
customer_id,
max(invoice_date) as last_purchase_date,
extract (day from (select max(invoice_date) from invoices) - max(invoice_date)) as days_since_last_purchase,
sum(total_amount) as lifetime_value
from invoices
group by customer_id
),
stats as(
select 
customer_id, 
days_since_last_purchase,
lifetime_value,
case
when days_since_last_purchase >= 180 then 'Churned'
when days_since_last_purchase >= 90 then 'At Risk'
when days_since_last_purchase >= 60 then 'Needs Attention'
else 'Active'
end as churn_category
from churn
)
select
churn_category,
count(*) as total_customers,
sum(lifetime_value) as total_revenue,
round(avg(lifetime_value),2) as avg_customer_value,
round((count(*) *100 / sum(count(*)) over()),2) as percentage
from stats
group by churn_category
order by 
case churn_category
when 'Active' then 1
when 'Needs Attention' then 2
when 'At Risk' then 3
when 'Churned' then 4
end


-- Query 15: Customer Lifetime Value
-- Question: What is the total lifetime value of each customer?


with clv as(
select
customer_id,
min(invoice_date) as first_purchase,
max(invoice_date) as last_purchase,
extract (day from max(invoice_date) - min(invoice_date)) as customer_lifespan,
sum(total_amount) as lifetime_value,
round(avg(total_amount),2) as per_order_value,
count(distinct invoice_no) as total_order,
extract (day from (select max(invoice_date) from invoices) - max(invoice_date)) as day_since_last_purchase
from invoices
group by customer_id
),

score as(
select
*,
case 
when customer_lifespan > 0
then round(total_order / (customer_lifespan/30),2) 
else total_order
end as orders_per_month,

case 
when lifetime_value >= 10000 then 4
when lifetime_value >= 5000 then 3
when lifetime_value >= 2000 then 2
else 1
end as value_score,

case 
when total_order >= 20 then 4
when total_order >= 10 then 3
when total_order >= 5 then 2
else 1
end as frequency_score,

case 
when day_since_last_purchase <=30 then 4
when day_since_last_purchase <=60 then 3
when day_since_last_purchase <=180 then 2
else 1
end as recency_score
from clv
)

select 
customer_id,
first_purchase,
last_purchase,
customer_lifespan,
total_order,
lifetime_value,
per_order_value,
day_since_last_purchase,
concat(value_score,recency_score,frequency_score) as clv_score,
case
when (value_score + recency_score + frequency_score) >= 11 then 'VIP'
WHEN (value_score + recency_score + frequency_score) >= 9 then 'High Value'
WHEN (value_score + recency_score + frequency_score) >= 6 then 'Medium Value'
else 'Low Value'
end as clv_stats,

case
when day_since_last_purchase >= 180 then 'Churned'
when day_since_last_purchase >= 90 then 'At Risk'
else 'Active'
end as churned_status
from score
order by lifetime_value desc, total_order desc


-- Customer Lifetime Value (CLV) Stats

	with clv as(
	select
	customer_id,
	min(invoice_date) as first_purchase,
	max(invoice_date) as last_purchase,
	extract (day from max(invoice_date) - min(invoice_date)) as customer_lifespan,
	sum(total_amount) as lifetime_value,
	round(avg(total_amount),2) as per_order_value,
	count(distinct invoice_no) as total_order,
	extract (day from (select max(invoice_date) from invoices) - max(invoice_date)) as day_since_last_purchase
	from invoices
	group by customer_id
	),
	
	score as(
	select
	*,
	case 
	when customer_lifespan > 0
	then round(total_order / (customer_lifespan/30),2) 
	else total_order
	end as orders_per_month,
	
	case 
	when lifetime_value >= 10000 then 4
	when lifetime_value >= 5000 then 3
	when lifetime_value >= 2000 then 2
	else 1
	end as value_score,
	
	case 
	when total_order >= 20 then 4
	when total_order >= 10 then 3
	when total_order >= 5 then 2
	else 1
	end as frequency_score,
	
	case 
	when day_since_last_purchase <=30 then 4
	when day_since_last_purchase <=60 then 3
	when day_since_last_purchase <=180 then 2
	else 1
	end as recency_score
	from clv
	),
	
	result as(
	select 
	customer_id,
	lifetime_value,
	per_order_value,
	total_order,
	case
	when (value_score + recency_score + frequency_score) >= 11 then 'VIP'
	WHEN (value_score + recency_score + frequency_score) >= 9 then 'High Value'
	WHEN (value_score + recency_score + frequency_score) >= 6 then 'Medium Value'
	else 'Low Value'
	end as clv_stats
	from score
	)
	select 
	clv_stats,
	count(*) customer_count,
	sum(lifetime_value) as total_clv,
	round(avg(lifetime_value),2)as avg_clv,
	round(avg(per_order_value),2) as per_order_value,
	round(avg(total_order),2) as avg_order_per_customer,
	round(count(*) * 100 / sum(count(*)) over(), 2) as percentage_of_customers,
	round(sum(lifetime_value) *100/sum(sum(lifetime_value)) over(),2) as pct_of_lifetime_value
	from result
	group by clv_stats
	order by 
	case clv_stats
	when 'VIP' then 1
	when 'High Value' then 2
	when 'Medium Value' then 3
	when 'Low Value' then 4
	end 

-- Query 16: Market Basket Analysis
-- Question: Which products are frequently purchased together in the same order?	

with mba as (
select ii1.stock_code as p1_stock_code, 
p1.product_name as p1_product_name, 
ii2.stock_code as p2_stock_code, 
p2.product_name as p2_product_name, 
count(distinct ii1.invoice_no) as cnt
from invoice_items ii1
inner join invoice_items ii2 on ii1.invoice_no = ii2.invoice_no 
and ii1.stock_code > ii2.stock_code
inner join products p1 on p1.stock_code = ii1.stock_code
inner join products p2 on p2.stock_code = ii2.stock_code
where ii1.quantity > 0 and ii2.quantity > 0
group by ii1.stock_code, p1.product_name, ii2.stock_code, p2.product_name
),

stock_freq as (
select stock_code, count(distinct invoice_no) as product_count
from invoice_items
where quantity > 0
group by stock_code
),

total_orders as (
select count(distinct invoice_no) as total_count
from invoices
where total_amount > 0
)

select mba.p1_stock_code, 
mba.p1_product_name, 
mba.p2_stock_code, 
mba.p2_product_name,
mba.cnt, 
round(mba.cnt * 100.0 / s1.product_count, 2) as confidence_pct, 
round((mba.cnt * 1.0 / s1.product_count) / nullif(s2.product_count * 1.0 / t.total_count, 0), 2) as lift
from mba
inner join stock_freq s1 on mba.p1_stock_code = s1.stock_code
inner join stock_freq s2 on mba.p2_stock_code = s2.stock_code
cross join total_orders t
where mba.cnt >= 10
order by mba.cnt desc, lift desc
limit 30;


-- Query 17: Cohort Retention Analysis
-- Question: What percentage of customers from each monthly cohort make repeat purchases?

with cohort_month as (
select
customer_id,
to_char(min(invoice_date), 'yyyy-mm') as cohort_month,
min(invoice_date) as first_purchase
from invoices
where total_amount > 0
group by customer_id
),

finding_month as(
select 
c.customer_id,
c.cohort_month,
c.first_purchase,
to_char(invoice_date, 'yyyy-mm') as active_month,
(date_trunc('month', invoice_date)::date - date_trunc('month', c.first_purchase)::date)/30 as month_index
from invoices i
join cohort_month c on i.customer_id = c.customer_id
where i.total_amount>0
),

cohort_total as(
select
f.cohort_month,
f.month_index,
count(distinct f.customer_id) as active_customers
from finding_month f
group by cohort_month, month_index
),

by_month as(
select 
fm.cohort_month,
count(distinct fm.customer_id) as customers
from finding_month fm
group by fm.cohort_month
)

select
cr.cohort_month,
bm.customers,
coalesce(cr.m0, 0) as m0,
coalesce(round(cr.m0_pct,1), 0) as m0_pct,
coalesce(cr.m1, 0) as m0,
coalesce(round(cr.m1_pct,1), 0) as m1_pct,
coalesce(cr.m2, 0) as m0,
coalesce(round(cr.m2_pct,1), 0) as m2_pct,
coalesce(cr.m3, 0) as m0,
coalesce(round(cr.m3_pct,1), 0) as m3_pct,
coalesce(cr.m4, 0) as m0,
coalesce(round(cr.m4_pct,1), 0) as m4_pct,
coalesce(cr.m5, 0) as m0,
coalesce(round(cr.m5_pct,1), 0) as m5_pct
from by_month bm
left join (
select 
cohort_month,
max(case when month_index = 0 then active_customers end) as m0,
max(case when month_index = 1 then active_customers end) as m1,
max(case when month_index = 2 then active_customers end) as m2,
max(case when month_index = 3 then active_customers end) as m3,
max(case when month_index = 4 then active_customers end) as m4,
max(case when month_index = 5 then active_customers end) as m5,
round(max(case when month_index = 0 then active_customers end) *100.0 
/ max(max(case when month_index = 0 then active_customers end)) over (partition by cohort_month),2) as m0_pct,
round(max(case when month_index = 1 then active_customers end) *100.0 
/ max(max(case when month_index = 0 then active_customers end)) over (partition by cohort_month),2) as m1_pct,
round(max(case when month_index = 2 then active_customers end) *100.0 
/ max(max(case when month_index = 0 then active_customers end)) over (partition by cohort_month),2) as m2_pct,
round(max(case when month_index = 3 then active_customers end) *100.0 
/ max(max(case when month_index = 0 then active_customers end)) over (partition by cohort_month),2) as m3_pct,
round(max(case when month_index = 4 then active_customers end) *100.0 
/ max(max(case when month_index = 0 then active_customers end)) over (partition by cohort_month),2) as m4_pct,
round(max(case when month_index = 5 then active_customers end) *100.0 
/ max(max(case when month_index = 0 then active_customers end)) over (partition by cohort_month),2) as m5_pct
from cohort_total
group by cohort_month
) cr on bm.cohort_month = cr.cohort_month
order by cr.cohort_month

-- Query 18: Product Performance by Customer Segment
-- Question: What product categories do high-value customers prefer vs low-value customers?

with customer_value as(
select 
customer_id,
sum(total_amount) as total_spend
from invoices
where total_amount > 0
group by customer_id
),

percentile as(
select
percentile_cont(0.75) within group (order by total_spend) as p75,
percentile_cont(0.25) within group (order by total_spend) as p25
from customer_value
),

segmentation as(
select 
customer_id,
total_spend,
case 
when total_spend >= p.p75 then 'High Value'
when total_spend >= p.p25 then 'Medium Value'
else 'Low Value'
end as stats
from customer_value
cross join percentile p
)

select
s.stats,
p.product_name,
sum(ii.quantity * ii.unit_price) as revenue,
count(distinct ii.invoice_no) as purchase_frequency
from segmentation s
join invoices i on s.customer_id = i.customer_id
join invoice_items ii on i.invoice_no = ii.invoice_no
join products p on ii.stock_code = p.stock_code
where i.total_amount>0 and ii.quantity > 0
group by s.stats, p.product_name


-- Query 19: Average Order Composition
-- Question: How many items and categories does an average order contain?

with cte as(
select 
ii.invoice_no,
sum(ii.quantity) total_items,
count(distinct ii.stock_code) as unique_product,
i.total_amount
from invoice_items ii
join invoices i on i.invoice_no = ii.invoice_no
and ii.quantity > 0 and i.total_amount > 0
group by ii.invoice_no, i.total_amount
having sum(ii.quantity) < 500
)

select 
round(avg(total_items),2) as avg_items,
round(avg(unique_product),2) as avg_unique_product,
round(avg(total_amount),2) as avg_order_value,
round(min(total_items),2) as min_items,
round(max(total_items),2) as max_items,
percentile_cont(0.5) within group (order by total_items) as median_items
from cte


-- Query 20: Repeat Purchase Rate
-- Question: What percentage of customers make more than one purchase?

with cte as(
select
customer_id,
count(distinct invoice_no) as purchase_count
from invoices
where total_amount > 0
group by customer_id
),

segment as (
select 
count(*) as total_customer,
sum(case when purchase_count = 1 then 1 else 0 end) as one_time_customer,
sum(case when purchase_count > 1 then 1 else 0 end) as repeat_customer,
sum(case when purchase_count > 10 then 1 else 0 end) as loyal_customer
from cte
)

select 
*,
round(one_time_customer*100.0/total_customer,2) as one_time_customer_pct,
round(repeat_customer*100.0/total_customer,2) as repeat_customer_pct,
round(loyal_customer*100.0/total_customer,2) as loyal_customer_pct
from segment


-- Query 20B: Repeat Purchase Rate by Country

with cte as(
select
customer_id,
country,
count(distinct invoice_no) as purchase_count
from invoices
where total_amount > 0
group by customer_id, country
),

segment as (
select 
country,
count(*) as total_customer,
sum(case when purchase_count = 1 then 1 else 0 end) as one_time_customer,
sum(case when purchase_count > 1 then 1 else 0 end) as repeat_customer,
sum(case when purchase_count > 10 then 1 else 0 end) as loyal_customer
from cte
group by country
)

select 
*,
round(one_time_customer*100.0/total_customer,2) as one_time_customer_pct,
round(repeat_customer*100.0/total_customer,2) as repeat_customer_pct,
round(loyal_customer*100.0/total_customer,2) as loyal_customer_pct
from segment
order by total_customer desc
limit 10


