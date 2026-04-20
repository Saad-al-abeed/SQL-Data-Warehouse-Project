# Data Warehouse ETL Pipeline project

## Overview
This project implements an end-to-end Data Warehouse ETL (Extract, Transform, Load) pipeline using PostgreSQL. It leverages the **Medallion Architecture** (Bronze, Silver, and Gold layers) and models a canonical **Star Schema** to consolidate and transform sales and customer data coming from disparate CRM and ERP systems.

The goal of this pipeline is to ingest raw CSV data, perform vigorous data cleaning and standardization, and load the enriched data into a dimensional model optimized for fast Business Intelligence (BI) and analytics querying.

## Architecture

This project is structured around the Medallion Architecture data design pattern:

### 1. Bronze Layer (Raw Data)
- **Purpose**: Ingest raw data from source systems "as-is" into the data warehouse.
- **Source Systems**: 
  - **CRM**: Customer Information (`crm_cust_info`), Product Information (`crm_prd_info`), Sales Details (`crm_sales_details`).
  - **ERP**: Customer mapping (`erp_cust_az12`), Location data (`erp_loc_a101`), Product Categories (`erp_px_cat_g1v2`).
- **Mechanism**: The `bronze_load.sql` script uses the PostgreSQL `COPY` command to bulk insert data from CSV files located in a staging directory (`/tmp/etl_staging/`) into the `bronze` schema tables. Before inserting, the target tables are truncated to execute a full-load pattern.

### 2. Silver Layer (Cleansed & Conformed Data)
- **Purpose**: Cleanse, normalize, and restructure the Bronze layer data.
- **Transformations**: 
  - **Data Standardization**: Normalization of gender, marital status, and country codes (e.g., standardizing 'F' and 'FEMALE' to 'Female'). 
  - **Data Cleansing**: Handling missing or null values (e.g., replacing null marital status with 'n/a'), removing extra spaces, dealing with invalid dates (e.g., stripping future birthdates).
  - **Business Logic Integration**: Deriving and double-checking fields, such as calculating `sls_sales` from `sls_quantity * sls_price` or deriving categorical mapping. 
  - **Metadata tracking**: Using a `dwh_create_date` column to track insertion time.
- **Mechanism**: Data is selected from the Bronze schema with PL/pgSQL routines (`silver_load.sql`) matching the transformations to insert into `silver` schema tables. It also checks for the most recent valid record using `row_number()`.

### 3. Gold Layer (Curated & Dimensional Data)
- **Purpose**: Expose curated and business-ready data optimized for reporting via a dimensional Star Schema.
- **Data Model**:
  - **Dimensions**:
    - `dim_customers`: Unified customer dimension joining data from CRM and ERP sources. Employs surrogate keys (`customer_key`).
    - `dim_products`: Unified product dimension categorizing product lines and their statuses. Filters for currently active products utilizing valid date ranges (`prd_end_dt is null`). 
  - **Fact**:
    - `fact_sales`: Centralized sales transaction facts linking to dimensions with appropriate foreign surrogate keys.
- **Mechanism**: The Gold layer is constructed using Database Views (`gold_layer.sql`) seamlessly joining and aggregating cleansed tables from the Silver layer.

## Data Quality Assurance

Robust data quality checks are embedded via SQL scripts to enforce constraints and referential integrity across transitions:
- **Silver Checks (`silver_checks.sql`)**: 
  - Ensures primary key integrity (no nulls or duplicates).
  - Validates formatting (unwanted whitespace removal).
  - Ensures date range consistency (start dates precede end dates, valid birth dates).
  - Validates business logic math (Sales = Quantity x Price).
- **Gold Checks (`gold_checks.sql`)**:
  - Confirms identical referential integrity (e.g. left join checks ensuring facts properly map to active dimension keys).
  - Primary key exclusivity for dimensional surrogate keys.

## Project Structure

```text
├── init_db.sql        # Creates DB and Bronze, Silver, Gold schemas
├── bronze_ddl.sql     # Drop and create statements for Bronze schema tables
├── bronze_load.sql    # Contains the `BRONZE_LOAD` stored procedure moving CSV->Bronze
├── silver_ddl.sql     # Drop and create statements for Silver schema tables with metadata
├── silver_load.sql    # Contains the `SILVER_LOAD` stored procedure executing transformations
├── silver_checks.sql  # SQL queries validating data consistency and cleanliness in Silver
├── gold_layer.sql     # Builds Star Schema views (Fact and Dimension)
├── gold_checks.sql    # SQL queries ensuring Star Schema referential integrity
└── source_crm/        # Additional raw source info (if applicable)
└── source_erp/        # Additional raw source info (if applicable)
```

## Setup & Deployment Instructions

### Prerequisites
- A properly running instance of **PostgreSQL**.
- Staging CSV datasets stored in `/tmp/etl_staging/`. Specifically, ensure the following files exist and match schemas:
  - `cust_info.csv`
  - `prd_info.csv`
  - `sales_details.csv`
  - `CUST_AZ12.csv`
  - `LOC_A101.csv`
  - `PX_CAT_G1V2.csv`

### Execution Steps
1. **Initialize Database**:
   Run `init_db.sql` to create the `DataWarehouse` database and the three medallion schemas (`bronze`, `silver`, `gold`).
2. **Build and Load Bronze**: 
   - Execute `bronze_ddl.sql` to set up table structures.
   - Run `bronze_load.sql` to execute the COPY statements dumping raw CSVs into Bronze tables.
3. **Build and Load Silver**:
   - Execute `silver_ddl.sql` to specify constraints and metadata extensions for Silver tables.
   - Run `silver_load.sql` which enforces standardizations and cleanses Bronze data into Silver tables.
   - Run `silver_checks.sql` and ensure all queries return 0 rows to validate cleanliness.
4. **Build Gold**:
   - Execute `gold_layer.sql` to compile the views defining the business intelligence Star Schema.
   - Run `gold_checks.sql` guaranteeing all relations resolve perfectly.

## Technologies Used
- **Database**: PostgreSQL
- **Language**: SQL (ANSI SQL compliant with PL/pgSQL procedures)
- **Architecture**: Medallion Architecture (Bronze / Silver / Gold), Dimensional Modeling (Star Schema)
