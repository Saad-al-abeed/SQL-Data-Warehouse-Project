# Data Catalog

This Data Catalog serves as the comprehensive data dictionary and architectural guide for the Enterprise Data Warehouse (EDW) implemented using the **Medallion Architecture** on PostgreSQL.

## 1. Architectural Overview

The EDW utilizes a three-tier architecture to securely and effectively transform raw data into report-ready structures. 

- **Bronze Layer (Raw Data)**: Stage area for immutable incoming data directly originating from source systems. There is a 1:1 parity with source tables, and data types are often kept as strings or integers directly transcribed from CSVs to avoid type coercion errors upon ingestion.
- **Silver Layer (Cleansed Target)**: Provides a trusted source of enterprise data. Data fields are cast to appropriate data types (dates, timestamps, exact metrics). Strings are trimmed, constants normalized, invalid data stripped or recomputed, and source system errors corrected.
- **Gold Layer (Curated for Consumption)**: Project-specific or subject-area structured data tables and views built specifically for downstream BI analysis. Adopts a Star Schema methodology, utilizing surrogate keys for historized data.

---

## 2. Source Systems

- **CRM (Customer Relationship Management)**: Provides base entities for Customers, Products, and detailed Sales transaction activities.
- **ERP (Enterprise Resource Planning)**: Provides secondary enrichment data, such as legacy customer mappings, geographical locations, and master product categorizations.

---

## 3. Bronze Layer Dictionary

**Schema**: `bronze`

### 3.1 `bronze.crm_cust_info`
Raw customer information coming from the CRM.
- `cst_id` (`INT`): Unique identifier for the customer.
- `cst_key` (`VARCHAR(50)`): External reference key.
- `cst_firstname` (`VARCHAR(50)`): First name.
- `cst_lastname` (`VARCHAR(50)`): Last name.
- `cst_marital_status` (`VARCHAR(50)`): Raw marital status code (e.g., 'S', 'M').
- `cst_gndr` (`VARCHAR(50)`): Raw gender code (e.g., 'F', 'M').
- `cst_create_date` (`DATE`): Date the record was created.

### 3.2 `bronze.crm_prd_info`
Raw product inventory characteristics from CRM.
- `prd_id` (`INT`): Product identifier.
- `prd_key` (`VARCHAR(50)`): Formatted string identifying category and product ID.
- `prd_nm` (`VARCHAR(50)`): Product name.
- `prd_cost` (`NUMERIC`): Direct cost.
- `prd_line` (`VARCHAR(50)`): Product line identifier code (e.g., 'M', 'R').
- `prd_start_dt` (`DATE`): Start of product's operational timeline.
- `prd_end_dt` (`DATE`): Expiration or phase-out date.

### 3.3 `bronze.crm_sales_details`
Raw sales transactions. Dates are initially read as integers.
- `sls_ord_num` (`VARCHAR(50)`): Order serial number.
- `sls_prd_key` (`VARCHAR(50)`): FK tying to the literal `prd_key` in CRM Products.
- `sls_cust_id` (`INT`): FK tying to the `cst_id` in CRM Customers.
- `sls_order_dt` (`INT`): Raw date format for Order placed.
- `sls_ship_dt` (`INT`): Raw date format for Order shipped.
- `sls_due_dt` (`INT`): Raw date format for Order due.
- `sls_sales` (`INT`): Total amount of sales transaction.
- `sls_quantity` (`INT`): Quantity of item purchased.
- `sls_price` (`NUMERIC`): Retail price per individual unit.

### 3.4 `bronze.erp_cust_az12`
Legacy customer details from ERP system.
- `CID` (`VARCHAR(50)`): Customer identifier string. Matches `crm_cust_info.cst_key`.
- `BDATE` (`DATE`): Customer Birthdate.
- `GEN` (`VARCHAR(50)`): Customer gender metadata.

### 3.5 `bronze.erp_loc_a101`
Location details for ERP mapped customers.
- `CID` (`VARCHAR(50)`): Customer identifier string.
- `CNTRY` (`VARCHAR(50)`): Origin or mapping country (Standard ISO/descriptive).

### 3.6 `bronze.erp_px_cat_g1v2`
Master product hierarchy tracking across categories and subcategories.
- `ID` (`VARCHAR(50)`): Identifier corresponding to category substrings in CRM product keys.
- `CAT` (`VARCHAR(50)`): Main global category.
- `SUBCAT` (`VARCHAR(50)`): Specialized subcategory.
- `MAINTENANCE` (`VARCHAR(50)`): ERP maintenance lifecycle marker.

---

## 4. Silver Layer Dictionary

**Schema**: `silver`

*Note: All Silver tables feature an overarching auditable timestamp `dwh_create_date` (`TIMESTAMP DEFAULT CURRENT_TIMESTAMP`) monitoring exactly when data was modeled from Bronze to Silver.*

### 4.1 `silver.crm_cust_info`
*Transformation logic*: Removes duplicates ensuring the most recent updated `cst_create_date` is kept per customer ID. `cst_marital_status` parsed explicitly into 'Single'/'Married'. `cst_gndr` explicitly scaled to 'Female'/'Male'. Missing mappings default to 'n/a'. Text arrays are trimmed.

### 4.2 `silver.crm_prd_info`
*Transformation logic*: Cost converted robustly to integer standard. `cat_id` explicitly extracted by parsing string bounds of the `prd_key`. Validates `prd_line` explicit enumerations ('Mountain', 'Road', 'Other Sales', 'Touring'). Derives historical window functions to ascertain proper `prd_end_dt` dates natively tracking product change-overs.

### 4.3 `silver.crm_sales_details`
*Transformation logic*: All numeric dates (`sls_order_dt`, `sls_ship_dt`, `sls_due_dt`) effectively cast via formatting to verifiable PostgreSQL `DATE` types. Validates `sls_sales` = `sls_quantity` * `sls_price`, and performs reverse imputation if there is missing data (e.g. if Price missing --> Sales / Quantity).

### 4.4 `silver.erp_cust_az12`
*Transformation logic*: Re-formats legacy ID prefixes ('NAS' removed). Protects and standardizes birthdates: strips out impossible future birthdates to `NULL`. Enumerates the varying `GEN` column text arrays correctly into 'Female' / 'Male'. 

### 4.5 `silver.erp_loc_a101`
*Transformation logic*: Fixes the dashed `-` keys in CID for valid mapping against CRM identifiers. Standardizes typical ISO codes (e.g. 'DE' --> 'Germany', 'US' --> 'United States'). Blank regions return 'n/a'. 

### 4.6 `silver.erp_px_cat_g1v2`
*Transformation logic*: Re-mapped 1:1, explicitly clearing formatting noise and whitespace.

---

## 5. Gold Layer Dictionary (Star Schema)

**Schema**: `gold`

The gold views implement a final dimensional model ready for analytics.

### 5.1 `gold.dim_customers`
A Type 1 slowly changing dimension constructed by joining `silver.crm_cust_info`, `silver.erp_cust_az12`, and `silver.erp_loc_a101`.
- `customer_key` (`BIGINT`): Auto-generated **Surrogate Key**.
- `customer_id` (`INT`): Natural/Source CRM ID.
- `customer_number` (`VARCHAR`): CRM key used across systems.
- `first_name` (`VARCHAR`): Trimmed customer first name.
- `last_name` (`VARCHAR`): Trimmed customer last name.
- `country` (`VARCHAR`): Geographic attribute originating from ERP locational data.
- `marital_status` (`VARCHAR`): CRM marital status.
- `gender` (`VARCHAR`): Consolidated gender logic (defers to ERP if CRM is absent).
- `birthdate` (`DATE`): Customer biographical birthdate originating from ERP.
- `create_date` (`DATE`): Sign-up or origin timestamp from CRM.

### 5.2 `gold.dim_products`
A valid, point-in-time product catalogue joining `silver.crm_prd_info` against ERP taxonomies `silver.erp_px_cat_g1v2`. Filters entirely for active, current items (`prd_end_dt IS NULL`).
- `product_key` (`BIGINT`): Auto-generated **Surrogate Key** tied to the specific product and its exact timeline.
- `product_id` (`INT`): CRM product identifier.
- `product_number` (`VARCHAR`): Descriptive key.
- `product_name` (`VARCHAR`): Name.
- `category_id` (`VARCHAR`): Foreign reference identifying category.
- `category` (`VARCHAR`): ERP Master Main Category label.
- `subcategory` (`VARCHAR`): ERP Master Specialized Subcategory label.
- `maintenance` (`VARCHAR`): ERP classification.
- `cost` (`INT`): Financial valuation per item.
- `product_line` (`VARCHAR`): Line category grouping.
- `start_date` (`DATE`): Point where product became systemably active. 

### 5.3 `gold.fact_sales`
A centralized transaction repository measuring point-of-sale activities explicitly mapped to dimensional surrogate keys for OLAP speed queries. 
- `order_number` (`VARCHAR`): Actual business transaction identifier.
- `product_key` (`BIGINT`): **Foreign Surrogate Key** mapped perfectly into `dim_products`.
- `customer_key` (`BIGINT`): **Foreign Surrogate Key** mapped perfectly into `dim_customers`.
- `order_date` (`DATE`): Time metric, when purchase initiated.
- `shipping_date` (`DATE`): Time metric, handling operations.
- `due_date` (`DATE`): Time metric, transaction expected finalized state.
- `sales_amount` (`INT`): Cleaned absolute financial transaction revenue metric.
- `quantity` (`INT`): Cleaned absolute units bought metric.
- `price` (`INT`): Cleaned absolute price-per-unit metric (derived appropriately if initially absent).
