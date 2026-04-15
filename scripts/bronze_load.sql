-- Loading into bronze layer: Full Load

create or replace procedure bronze.BRONZE_LOAD()
language plpgsql as $$

declare
	cnt int;
begin

truncate bronze.crm_cust_info;
copy bronze.crm_cust_info 
from '/tmp/etl_staging/cust_info.csv'
with (format csv, header true, delimiter ',');

select count(*) from bronze.crm_cust_info into cnt;
raise notice '% rows successfully loaded into crm_cust_info', cnt;

truncate bronze.crm_prd_info;
copy bronze.crm_prd_info 
from '/tmp/etl_staging/prd_info.csv'
with (format csv, header true, delimiter ',');

select count(*) from bronze.crm_prd_info into cnt;
raise notice '% rows successfully loaded into crm_prd_info', cnt;

truncate bronze.crm_sales_details;
copy bronze.crm_sales_details 
from '/tmp/etl_staging/sales_details.csv'
with (format csv, header true, delimiter ',');

select count(*) from bronze.crm_sales_details into cnt;
raise notice '% rows successfully loaded into crm_sales_details', cnt;

truncate bronze.erp_cust_az12;
copy bronze.erp_cust_az12 
from '/tmp/etl_staging/CUST_AZ12.csv'
with (format csv, header true, delimiter ',');

select count(*) from bronze.erp_cust_az12 into cnt;
raise notice '% rows successfully loaded into erp_cust_az12', cnt;

truncate bronze.erp_loc_a101;
copy bronze.erp_loc_a101 
from '/tmp/etl_staging/LOC_A101.csv'
with (format csv, header true, delimiter ',');

select count(*) from bronze.erp_loc_a101 into cnt;
raise notice '% rows successfully loaded into erp_loc_a101', cnt;

truncate bronze.erp_px_cat_g1v2;
copy bronze.erp_px_cat_g1v2 
from '/tmp/etl_staging/PX_CAT_G1V2.csv'
with (format csv, header true, delimiter ',');

select count(*) from bronze.erp_px_cat_g1v2 into cnt;
raise notice '% rows successfully loaded into erp_px_cat_g1v2', cnt;

end;
$$;

-- executing the bronze layer full load
call bronze.BRONZE_LOAD();