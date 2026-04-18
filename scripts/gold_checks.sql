-- checking 'gold.dim_customers'

select 
    customer_key,
    count(*) as duplicate_count
from gold.dim_customers
group by customer_key
having count(*) > 1;
-- should return nothing


-- checking 'gold.dim_products'

select 
    product_key,
    count(*) as duplicate_count
from gold.dim_products
group by product_key
having count(*) > 1;
-- should return nothing

-- checking 'gold.fact_sales'

select * from gold.fact_sales f
left join gold.dim_customers c
    on c.customer_key = f.customer_key
left join gold.dim_products p
    on p.product_key = f.product_key
where p.product_key is null 
   or c.customer_key is null;
-- should return nothing