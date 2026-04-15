-- Silver layer quality checking

-- checking silver.crm_cust_info

-- check for nulls or duplicates in primary key
-- expectation: no results
select 
    cst_id,
    count(*) 
from silver.crm_cust_info
group by cst_id
having count(*) > 1 or cst_id is null;

-- check for unwanted spaces
-- expectation: no results
select 
    cst_key 
from silver.crm_cust_info
where cst_key != trim(cst_key);

-- data standardization & consistency
select distinct 
    cst_marital_status 
from silver.crm_cust_info;

-- checking silver.crm_prd_info

-- check for nulls or duplicates in primary key
-- expectation: no results
select 
    prd_id,
    count(*) 
from silver.crm_prd_info
group by prd_id
having count(*) > 1 or prd_id is null;

-- check for unwanted spaces
-- expectation: no results
select 
    prd_nm 
from silver.crm_prd_info
where prd_nm != trim(prd_nm);

-- check for nulls or negative values in cost
-- expectation: no results
select 
    prd_cost 
from silver.crm_prd_info
where prd_cost < 0 or prd_cost is null;

-- data standardization & consistency
select distinct 
    prd_line 
from silver.crm_prd_info;

-- check for invalid date orders (start date > end date)
-- expectation: no results
select 
    * from silver.crm_prd_info
where prd_end_dt < prd_start_dt;

-- checking silver.crm_sales_details

-- check for invalid dates
-- expectation: no invalid dates
select 
    nullif(sls_due_dt, 0) as sls_due_dt 
from bronze.crm_sales_details
where sls_due_dt <= 0 
    or length(cast(sls_due_dt as varchar)) != 8 
    or sls_due_dt > 20500101 
    or sls_due_dt < 19000101;

-- check for invalid date orders (order date > shipping/due dates)
-- expectation: no results
select 
    * from silver.crm_sales_details
where sls_order_dt > sls_ship_dt 
   or sls_order_dt > sls_due_dt;

-- check data consistency: sales = quantity * price
-- expectation: no results
select distinct 
    sls_sales,
    sls_quantity,
    sls_price 
from silver.crm_sales_details
where sls_sales != sls_quantity * sls_price
   or sls_sales is null 
   or sls_quantity is null 
   or sls_price is null
   or sls_sales <= 0 
   or sls_quantity <= 0 
   or sls_price <= 0
order by sls_sales, sls_quantity, sls_price;

-- checking silver.erp_cust_az12

-- identify out-of-range dates
-- expectation: birthdates between 1924-01-01 and today
select distinct 
    bdate 
from silver.erp_cust_az12
where bdate < '1924-01-01' 
   or bdate > current_date;

-- data standardization & consistency
select distinct 
    gen 
from silver.erp_cust_az12;

-- checking silver.erp_loc_a101

-- data standardization & consistency
select distinct 
    cntry 
from silver.erp_loc_a101
order by cntry;

-- checking silver.erp_px_cat_g1v2

-- check for unwanted spaces
-- expectation: no results
select 
    * from silver.erp_px_cat_g1v2
where cat != trim(cat) 
   or subcat != trim(subcat) 
   or maintenance != trim(maintenance);

-- data standardization & consistency
select distinct 
    maintenance 
from silver.erp_px_cat_g1v2;