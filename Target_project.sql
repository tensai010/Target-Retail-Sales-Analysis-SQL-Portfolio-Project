SELECT * FROM sales
SELECT * FROM stores
SELECT * FROM products
SELECT * FROM customers


/* Top 5 Selling Products by Quantity */
--join sales and products
-- sum(quantity) 
-- group by and order by
SELECT
	p.product_name,
	sum(s.quantity) as total_quantity_sold
FROM products p
JOIN sales s
ON p.product_id = s.product_id
GROUP BY p.product_name
ORDER BY total_quantity_sold DESC
LIMIT 5;


/* Total Revenue by Product Category */
--join sales and products
--sum(price * qty)
-- group by category
SELECT 
	p.category,
	sum(p.price * s.quantity) as total_revenue
FROM products p
JOIN sales s
ON p.product_id = s.product_id
GROUP BY p.category;

/*Monthly Sales Trend for 2024 */
--join sales and products
--sum(price * qty)
--extract(month from sale_date)
--filter 2024 year
--group by month
SELECT 
	EXTRACT(MONTH FROM s.sale_date) as month,
	sum(p.price * s.quantity) as total_revenue
FROM products p
JOIN sales s
ON p.product_id = s.product_id
WHERE  EXTRACT(YEAR FROM s.sale_date) = 2024
GROUP BY EXTRACT(MONTH FROM s.sale_date);


/*  Top 3 Stores by Revenue */
--join sales-products-store
--sum(price * qty)
--group by store_name
--limit 3
SELECT 
	ss.store_name,
	sum(p.price * s.quantity) as total_revenue
FROM sales s
JOIN products p
ON s.product_id = p.product_id
JOIN stores ss
ON ss.store_id = s.store_id
GROUP BY ss.store_name
ORDER BY total_revenue
LIMIT 3;

/* Customer retention
How many customers made repeat purchases (more than 2 sale)? */
--join sales and customers
--count dist customer_id
--group by c.customer_name
--having filer > 2

SELECT 
	c.full_name as customer_name,
	count(DISTINCT s.customer_id) as total_customers
FROM customers c
JOIN sales s
ON c.customer_id = s.customer_id
GROUP BY 1
HAVING count(DISTINCT c.customer_id) >=2
ORDER BY total_customers DESC;


/*Most popular product in each category (by units sold) */
--join sales and products
--sum(s.qty)
--rank func -- partition by category-- orderby s.quantity
--group by product_name and category
-- cte-- filter by ranked_items 
with cte as
(SELECT 
	p.product_name,
	p.category,
	sum(s.quantity) as total_qty_sold,
	rank() over(partition by p.category order by sum(s.quantity) desc ) ranked_items
FROM sales s
JOIN products p
ON s.product_id = p.product_id
GROUP BY p.category, p.product_name)
SELECT product_name, category, total_qty_sold from cte where ranked_items = 1;


/* Top 5 customers by total spend */
--join sales ,products and customers
--sum(qty * price)
--group by -- order by -- limit 5
SELECT
	c.full_name as cusomer_name,
	sum(p.price * s.quantity) as total_spend
FROM sales s
JOIN products p
ON s.product_id = p.product_id
JOIN customers c
ON c.customer_id = s.customer_id
GROUP BY 1 
ORDER BY total_spend DESC
LIMIT 5;

/*
Store performance: Show store revenue along with average basket size (items per transaction)
*/
-- join sales, stores and prodcuts
-- case statement
SELECT 
	ss.store_name,
	sum(case when s.quantity > 0 then s.quantity * p.price else 0 end) total_revenue,
	round(avg(case when s.quantity > 0 then s.quantity else null end),2) avg_basket_size
FROM sales s
JOIN stores ss
ON s.store_id = ss.store_id
JOIN products p
ON p.product_id = s.product_id
GROUP BY ss.store_name;

/*
Time between first and second purchase per customer
Return: customer_id, first_purchase, second_purchase, days_between
*/
-- join sales and customers
-- rownumber to assign rank to each purchase-- partition by customer_id and order by sale_date
-- cte-- filtering ranks <= 2 because we need only first and second 
-- cte-- case statement to get the max_date to get customers first and second purchase date 
-- cte - difference between first_purchase_date and second_purchase_date

with ranked_sales as
(SELECT 
	s.customer_id,
	c.full_name,
	s.sale_date,
	row_number() over(partition by s.customer_id order by s.sale_date) as rn
FROM sales s
JOIN customers c
ON s.customer_id = c.customer_id
WHERE s.quantity > 0), -- this excludes returns
first_two_orders as
(SELECT * FROM ranked_sales where rn <= 2),

pivoted as 
(select
	customer_id,
	full_name,
	max(case when rn = 1 then sale_date end) as first_purchase,
	max(case when rn = 2 then sale_date end) as second_purchase
from first_two_orders
group by customer_id,
	full_name)

SELECT 
	customer_id,
	full_name,
	second_purchase - first_purchase as days_between
FROM pivoted
where second_purchase is not null;

/* Top 3 Selling Products per Month */
-- join sales , products table
-- extract month from sale_sate
--sum(qty * price)
-- group by
-- cte and then rank
-- partition by month order by total_qty sold
with cte as
(SELECT
	EXTRACT(YEAR FROM s.sale_date) AS year,
	EXTRACT(MONTH FROM s.sale_date) AS month,
	p.product_name,
	sum(s.quantity) AS total_quantity_sold
FROM sales s
JOIN products p
ON s.product_id = p.product_id
GROUP BY 1,2,3),
ranked_months as
(SELECT *,
rank() over(partition by month,year order by total_quantity_sold desc)as rn
FROM cte)
SELECT 
	year,
	month,
	product_name,
	total_quantity_sold
FROM ranked_months
WHERE rn <= 3;

/*
Store Performance by Product Category
Goal: Calculate each store’s revenue contribution per product category and sort by highest contributors.
Return: store_name, category_name, total_revenue, percentage_of_store_revenue
*/


WITH category_revenue AS
(SELECT
	st.store_name,
	p.category,
	sum(p.price * s.quantity) as total_revenue
FROM sales s
JOIN products p
ON s.product_id = p.product_id
JOIN stores st
ON st.store_id = s.store_id
GROUP BY 1,2
),

total_store_revenue AS
(SELECT
	store_name,
	sum(total_revenue) AS store_total
FROM category_revenue
GROUP BY store_name)

SELECT
	cr.store_name,
	cr.category,
	ROUND((cr.total_revenue * 100.0/ tsr.store_total ),2) AS Percentage_of_store_contribution
FROM category_revenue AS cr
JOIN total_store_revenue AS tsr
ON cr.store_name = tsr.store_name
ORDER BY 1,3 DESC;


/*Customer Lifetime Value (CLV)
Goal: For each customer, calculate total revenue they've generated.
Return: customer_id, customer_name, lifetime_revenue, first_purchase_date, last_purchase_date
*/

SELECT
	s.customer_id,
	c.full_name as customer_name,
	sum(s.quantity * p.price) as lifetime_revenue,
	min(s.sale_date) as first_purchase_date,
	max(s.sale_date) as last_purchase_date
FROM sales s 
JOIN products p
ON s.product_id = p.product_id
JOIN customers c
ON s.customer_id = c.customer_id
GROUP BY 1,2
ORDER BY 3 DESC;


 /*Average Time Between Purchases (Customer Loyalty Metric)
Goal: For each customer, calculate the average number of days between purchases (if more than 1 order).
Return: customer_id, customer_name, avg_days_between_orders
*/
--join customer and sales
--lag function get the previous_purchase date 
--partition by customer_id and ordered by sale_date
-- cte, get the diff between sale date and prev_purch_date as days_between
--new cte, get the average of days_between
--group by
WITH purchase_dates AS
(SELECT 	
	s.customer_id,
	c.full_name AS customer_name,
	s.sale_date,
	LAG(s.sale_date) OVER(PARTITION BY s.customer_id ORDER BY s.sale_date) AS previous_purchase_date
FROM customers c
JOIN sales s
ON s.customer_id = c.customer_id
),

days_diff as
(SELECT
	customer_id,
	customer_name,
	--date_part('day',sale_date - previous_purchase_date) as days_between
	(sale_date - previous_purchase_date) as days_between
FROM purchase_dates
WHERE previous_purchase_date IS NOT NULL)

SELECT
	customer_id,
	customer_name,
	ROUND(AVG(days_between),2) AS avg_days_between_purchases
FROM days_diff
GROUP BY 1,2
ORDER BY 3 ASC



