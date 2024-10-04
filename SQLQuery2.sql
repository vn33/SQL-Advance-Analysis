drop table if exists goldusers_signup;
CREATE TABLE goldusers_signup(userid integer,gold_signup_date date); 

INSERT INTO goldusers_signup(userid,gold_signup_date) 
 VALUES (1,'09-22-2017'),
(3,'04-21-2017');

drop table if exists users;
CREATE TABLE users(userid integer,signup_date date); 

INSERT INTO users(userid,signup_date) 
 VALUES (1,'09-02-2014'),
(2,'01-15-2015'),
(3,'04-11-2014');

drop table if exists sales;
CREATE TABLE sales(userid integer,created_date date,product_id integer); 

INSERT INTO sales(userid,created_date,product_id) 
 VALUES (1,'04-19-2017',2),
(3,'12-18-2019',1),
(2,'07-20-2020',3),
(1,'10-23-2019',2),
(1,'03-19-2018',3),
(3,'12-20-2016',2),
(1,'11-09-2016',1),
(1,'05-20-2016',3),
(2,'09-24-2017',1),
(1,'03-11-2017',2),
(1,'03-11-2016',1),
(3,'11-10-2016',1),
(3,'12-07-2017',2),
(3,'12-15-2016',2),
(2,'11-08-2017',2),
(2,'09-10-2018',3);


drop table if exists product;
CREATE TABLE product(product_id integer,product_name text,price integer); 

INSERT INTO product(product_id,product_name,price) 
 VALUES
(1,'p1',980),
(2,'p2',870),
(3,'p3',330);

select * from sales;
select * from product;
select * from goldusers_signup;
select * from users;

-- 1. What is the total amount each customer spent on zomato?
SELECT a.userid, SUM(b.price) AS total_amt_spent
FROM sales a
INNER JOIN product b ON a.product_id = b.product_id
GROUP BY a.userid;

-- 2. How many days has each customer visited zomato
SELECT userid, COUNT(DISTINCT created_date) distinct_days FROM sales GROUP BY userid;

-- 3. What was the first product purchased by each customer?
SELECT *
FROM (
    SELECT *, RANK() OVER (PARTITION BY userid ORDER BY created_date) AS product_rank
    FROM sales
) a
WHERE product_rank = 1;


-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
WITH MostPurchasedProduct AS (
    SELECT TOP 1 product_id
    FROM sales
    GROUP BY product_id
    ORDER BY COUNT(product_id) DESC
)
SELECT userid, product_id, COUNT(product_id) AS product_cnt
FROM sales
WHERE product_id = (SELECT product_id FROM MostPurchasedProduct)
GROUP BY userid, product_id;


-- 5. Which item was the most popular for each customer?
SELECT userid, product_id, cnt, rnk
FROM (
    SELECT userid, product_id, COUNT(product_id) AS cnt,
           RANK() OVER (PARTITION BY userid ORDER BY COUNT(product_id) DESC) AS rnk
    FROM sales
    GROUP BY userid, product_id
) AS ranked_sales
WHERE rnk = 1;

-- 6. which item was purchased first by the customer after they became a member?
SELECT *
FROM (
    SELECT s.userid, s.created_date, s.product_id, g.gold_signup_date,
           RANK() OVER (PARTITION BY s.userid ORDER BY s.created_date) AS rnk
    FROM sales s
    INNER JOIN goldusers_signup g 
        ON s.userid = g.userid 
       AND s.created_date >= g.gold_signup_date
) AS ranked_purchases
WHERE rnk = 1;

-- 7. which item was purchased just before the customer become a member?
SELECT *
FROM (
    SELECT s.userid, s.created_date, s.product_id, g.gold_signup_date,
           RANK() OVER (PARTITION BY s.userid ORDER BY s.created_date DESC) AS rnk
    FROM sales s
    INNER JOIN goldusers_signup g 
        ON s.userid = g.userid 
       AND s.created_date <= g.gold_signup_date
) AS ranked_purchases
WHERE rnk = 1;

-- 8. What are the total orders and amount spent for each member before they became a member
SELECT p.userid, COUNT(p.created_date) AS order_purchased, SUM(p.price) AS total_amt_spent
FROM (
    SELECT s.userid, s.created_date, s.product_id, d.price
    FROM sales s
    INNER JOIN goldusers_signup g 
        ON s.userid = g.userid 
       AND s.created_date <= g.gold_signup_date
    INNER JOIN product d 
        ON s.product_id = d.product_id
) AS p
GROUP BY p.userid;

-- 9.If buying each product generates points for eg 5rs=2 zomato points and each product has different purchasing points
-- for eg for p1 5rs=1 zomato point,
-- for p2 10rs=5 zomato point
-- Calculate points collected by each customer and find out which product gave the most points
WITH PointsPerProduct AS (
    SELECT s.userid, s.product_id, SUM(p.price) AS amt,
           CASE 
               WHEN s.product_id = 1 THEN SUM(p.price) * (1.0 / 5)  -- For product 1: 1 point per ₹5
               WHEN s.product_id = 2 THEN SUM(p.price) * (5.0 / 10) -- For product 2: 5 points per ₹10
               WHEN s.product_id = 3 THEN SUM(p.price) * (5.0 / 5)  -- For product 3: 5 points per ₹5
               ELSE 0 
           END AS total_points
    FROM sales s
    INNER JOIN product p 
        ON s.product_id = p.product_id
    GROUP BY s.userid, s.product_id
),
TotalPointsPerUser AS (
    SELECT userid, SUM(total_points) * 2.5 AS total_cashbacks_earned
    FROM PointsPerProduct
    GROUP BY userid
),
MostPointsPerProduct AS (
    SELECT product_id, SUM(total_points) AS total_points_per_product
    FROM PointsPerProduct
    GROUP BY product_id
)
SELECT userid, total_cashbacks_earned, product_id, total_points_per_product
FROM TotalPointsPerUser
CROSS APPLY (
    SELECT TOP 1 product_id, total_points_per_product
    FROM MostPointsPerProduct
    ORDER BY total_points_per_product DESC
) AS MostPoints;

---OR---
SELECT userid, sum(total_points)* 2.5 AS total_cashbacks_earned
FROM
(SELECT e.*, amt/points AS total_points
FROM
(SELECT d.*, 
   CASE 
   WHEN d.product_id = 1 THEN 5  -- 5 point for product 1
   WHEN d.product_id = 2 THEN 2 -- 2 points for product 2
   WHEN d.product_id = 3 THEN 5 -- 5 points for product 3
   ELSE 0 
   END AS points
FROM (
SELECT s.userid, s.product_id, SUM(p.price) AS amt
FROM sales s
INNER JOIN product p 
ON s.product_id = p.product_id
GROUP BY s.userid, s.product_id
) AS d
) AS e
)AS f
GROUP BY userid;


-- Find the product with the highest total points earned
SELECT *
FROM (
    SELECT product_id, total_points_earned, 
           RANK() OVER(ORDER BY total_points_earned DESC) AS rnk
    FROM (
        SELECT product_id, SUM(total_points) AS total_points_earned
        FROM (
            SELECT b.*, amt / points AS total_points
            FROM (
                SELECT a.*, 
                       CASE 
                           WHEN a.product_id = 1 THEN 5  -- 5 points per Rs for product 1
                           WHEN a.product_id = 2 THEN 2  -- 2 points per Rs for product 2
                           WHEN a.product_id = 3 THEN 5  -- 5 points per Rs for product 3
                           ELSE 0 
                       END AS points
                FROM (
                    SELECT s.userid, s.product_id, SUM(p.price) AS amt
                    FROM sales s
                    INNER JOIN product p 
                        ON s.product_id = p.product_id
                    GROUP BY s.userid, s.product_id
                ) AS a
            ) AS b
        ) AS c
        GROUP BY product_id
    ) AS d
) AS e
WHERE rnk = 1;


-- 10. In the first one year after a customer joins the gold program (including their join date) irrespective
-- of what the customer has purchased they earn 5 zomato points for every 10rs spent who earned more 1 or 3
-- and what was their points earnings in their first year?
-- 1zp = 2 rs => 0.5 zp = 1 rs

SELECT c.*,d.price*0.5 total_points_earned FROM
(SELECT s.userid, s.created_date, s.product_id, g.gold_signup_date
FROM sales s
	INNER JOIN goldusers_signup g 
		ON s.userid = g.userid 
		AND s.created_date >= g.gold_signup_date
		AND s.created_date<= DATEADD(year, 1, g.gold_signup_date))c
	INNER JOIN product d on c.product_id = d.product_id;


-- 11. rank all transaction of the customers
SELECT *, RANK() OVER(PARTITION BY userid order by created_date) as rnk FROM sales;


-- 12. rank all the transactions for each member whenever they are a zomato gold member, for every non gold member
-- transaction mark as NA
SELECT a.*, 
       CASE 
           WHEN gold_signup_date IS NULL THEN 'NA' 
           ELSE CAST(RANK() OVER(PARTITION BY userid ORDER BY created_date DESC) AS VARCHAR)
       END AS rnk 
FROM (
    SELECT s.userid, s.created_date, s.product_id, g.gold_signup_date
    FROM sales s
    LEFT JOIN goldusers_signup g 
        ON s.userid = g.userid 
       AND s.created_date >= g.gold_signup_date
) a;



