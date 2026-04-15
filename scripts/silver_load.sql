-- Loading into silver layer from bronze layer
-- Full load with data transformationa and cleaning

create or replace procedure silver.SILVER_LOAD()

language plpgsql as $$

begin
    -- loading silver.crm_cust_info
    raise notice '>> truncating table: silver.crm_cust_info';
    truncate table silver.crm_cust_info;
    raise notice '>> inserting data into: silver.crm_cust_info';
    insert into silver.crm_cust_info (
        cst_id, 
        cst_key, 
        cst_firstname, 
        cst_lastname, 
        cst_marital_status, 
        cst_gndr,
        cst_create_date
    )
    select
        cst_id,
        cst_key,
        trim(cst_firstname) as cst_firstname,
        trim(cst_lastname) as cst_lastname,
        case 
            when upper(trim(cst_marital_status)) = 'S' then 'Single'
            when upper(trim(cst_marital_status)) = 'M' then 'Married'
            else 'n/a' -- Null value defaulted to not applicable
        end as cst_marital_status, -- normalize marital status values to readable format
        case 
            when upper(trim(cst_gndr)) = 'F' then 'Female'
            when upper(trim(cst_gndr)) = 'M' then 'Male'
            else 'n/a' -- Null value defaulted to not applicable
        end as cst_gndr, -- normalize gender values to readable format
        cst_create_date
    from (
        select
            *,
            row_number() over (partition by cst_id order by cst_create_date desc) as flag_last
        from bronze.crm_cust_info
        where cst_id is not null
    ) t
    where flag_last = 1; -- select the most recent record per customer

    -- loading silver.crm_prd_info
    raise notice '>> truncating table: silver.crm_prd_info';
    truncate table silver.crm_prd_info;
    raise notice '>> inserting data into: silver.crm_prd_info';
    insert into silver.crm_prd_info (
        prd_id,
        cat_id,
        prd_key,
        prd_nm,
        prd_cost,
        prd_line,
        prd_start_dt,
        prd_end_dt
    )
    select
        prd_id,
        replace(substring(prd_key, 1, 5), '-', '_') as cat_id, -- extract category id
        substring(prd_key, 7, length(prd_key)) as prd_key, -- extract product key
        prd_nm,
        coalesce(prd_cost, 0) as prd_cost,
        case 
            when upper(trim(prd_line)) = 'M' then 'Mountain'
            when upper(trim(prd_line)) = 'R' then 'Road'
            when upper(trim(prd_line)) = 'S' then 'Other Sales'
            when upper(trim(prd_line)) = 'T' then 'Touring'
            else 'n/a'
        end as prd_line, -- map product line codes to descriptive values
        cast(prd_start_dt as date) as prd_start_dt,
        -- calculate end date as one day before the next start date
        cast(
            lead(cast(prd_start_dt as date)) over (partition by prd_key order by cast(prd_start_dt as date)) - 1 
            as date
        ) as prd_end_dt 
    from bronze.crm_prd_info;

    -- loading crm_sales_details
    raise notice '>> truncating table: silver.crm_sales_details';
    truncate table silver.crm_sales_details;
    raise notice '>> inserting data into: silver.crm_sales_details';
    insert into silver.crm_sales_details (
        sls_ord_num,
        sls_prd_key,
        sls_cust_id,
        sls_order_dt,
        sls_ship_dt,
        sls_due_dt,
        sls_sales,
        sls_quantity,
        sls_price
    )
    select 
        sls_ord_num,
        sls_prd_key,
        sls_cust_id,
        case 
            when sls_order_dt = 0 or length(cast(sls_order_dt as varchar)) != 8 then null
            else cast(cast(sls_order_dt as varchar) as date)
        end as sls_order_dt,
        case 
            when sls_ship_dt = 0 or length(cast(sls_ship_dt as varchar)) != 8 then null
            else cast(cast(sls_ship_dt as varchar) as date)
        end as sls_ship_dt,
        case 
            when sls_due_dt = 0 or length(cast(sls_due_dt as varchar)) != 8 then null
            else cast(cast(sls_due_dt as varchar) as date)
        end as sls_due_dt,
        case 
            when sls_sales is null or sls_sales <= 0 or sls_sales != sls_quantity * abs(sls_price) 
                then sls_quantity * abs(sls_price)
            else sls_sales
        end as sls_sales, -- recalculate sales if original value is missing or incorrect
        sls_quantity,
        case 
            when sls_price is null or sls_price <= 0 
                then sls_sales / nullif(sls_quantity, 0)
            else sls_price  -- derive price if original value is invalid
        end as sls_price
    from bronze.crm_sales_details;

    -- loading erp_cust_az12
    raise notice '>> truncating table: silver.erp_cust_az12';
    truncate table silver.erp_cust_az12;
    raise notice '>> inserting data into: silver.erp_cust_az12';
    insert into silver.erp_cust_az12 (
        cid,
        bdate,
        gen
    )
    select
        case
            when CID like 'NAS%' then substring(CID, 4, length(CID)) -- remove 'NAS' prefix if present
            else CID
        end as CID, 
        case
            when cast(BDATE as date) > current_date then null
            else cast(BDATE as date)
        end as BDATE, -- set future birthdates to null
        case
            when upper(trim(GEN)) in ('F', 'FEMALE') then 'Female'
            when upper(trim(GEN)) in ('M', 'MALE') then 'Male'
            else 'n/a'
        end as GEN -- normalize gender values and handle unknown cases
    from bronze.erp_cust_az12;

    -- loading erp_loc_a101
    raise notice '>> truncating table: silver.erp_loc_a101';
    truncate table silver.erp_loc_a101;
    raise notice '>> inserting data into: silver.erp_loc_a101';
    insert into silver.erp_loc_a101 (
        cid,
        cntry
    )
    select
        replace(CID, '-', '') as CID, 
        case
            when trim(CNTRY) = 'DE' then 'Germany'
            when trim(CNTRY) in ('US', 'USA') then 'United States'
            when trim(CNTRY) = '' or CNTRY is null then 'n/a'
            else trim(CNTRY)
        end as CNTRY -- normalize and handle missing or blank country codes
    from bronze.erp_loc_a101;
    
    -- loading erp_px_cat_g1v2
    raise notice '>> truncating table: silver.erp_px_cat_g1v2';
    truncate table silver.erp_px_cat_g1v2;
    raise notice '>> inserting data into: silver.erp_px_cat_g1v2';
    insert into silver.erp_px_cat_g1v2 (
        id,
        cat,
        subcat,
        maintenance
    )
    select
        ID,
        CAT,
        SUBCAT,
        MAINTENANCE
    from bronze.erp_px_cat_g1v2;

end;
$$;

-- executing the silver layer full load
call silver.SILVER_LOAD();