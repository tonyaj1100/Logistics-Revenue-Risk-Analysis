-- ==============================================================================
-- PROJECT: Logistics Revenue Risk Analysis (VELOCITY Network)
-- SCRIPT: End-to-End ETL and Data Warehousing (Star Schema)
-- DATABASE: PostgreSQL
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- STEP 1: CREATE LANDING ZONE (STAGING TABLE)
-- ------------------------------------------------------------------------------
-- Creating a flat staging table to catch the raw cleaned CSV data from Python.
CREATE TABLE staging_deliveries (
    order_id INT,
    dark_store_name VARCHAR(50),
    customer_lat_lon VARCHAR(50),
    order_timestamp TIMESTAMP,
    cart_value_inr NUMERIC(10, 2),
    weather_condition VARCHAR(50),
    delivery_time_mins NUMERIC(10, 2),
    delivery_status VARCHAR(20)
);

-- ------------------------------------------------------------------------------
-- STEP 2: LOAD DATA INTO STAGING
-- ------------------------------------------------------------------------------
-- Utilizing the high-speed \copy command to ingest 50,000 rows from local CSV.
\copy staging_deliveries FROM 'Downloads/Logistics_Data_Warehouse_Project/cleaned_deliveries_50k.csv' WITH (FORMAT csv, HEADER true);

-- ------------------------------------------------------------------------------
-- STEP 3: CREATE DIMENSION TABLES
-- ------------------------------------------------------------------------------
-- Creating normalized dimension tables with automatically incrementing primary keys.

CREATE TABLE dim_hubs (
    hub_key SERIAL PRIMARY KEY,
    hub_name VARCHAR(50)
);

CREATE TABLE dim_weather (
    weather_key SERIAL PRIMARY KEY,
    condition_type VARCHAR(50)
);

-- ------------------------------------------------------------------------------
-- STEP 4: POPULATE DIMENSION TABLES
-- ------------------------------------------------------------------------------
-- Extracting distinct categorical values from staging to populate dimensions.

INSERT INTO dim_hubs (hub_name) 
SELECT DISTINCT dark_store_name FROM staging_deliveries;

INSERT INTO dim_weather (condition_type) 
SELECT DISTINCT weather_condition FROM staging_deliveries;

-- ------------------------------------------------------------------------------
-- STEP 5: CREATE FACT TABLE
-- ------------------------------------------------------------------------------
-- Creating the core fact table linked to dimensions via Foreign Keys.

CREATE TABLE fact_deliveries (
    delivery_key SERIAL PRIMARY KEY,
    order_id INT,
    order_timestamp TIMESTAMP,
    cart_value_inr NUMERIC(10, 2),
    delivery_time_mins NUMERIC(10, 2),
    delivery_status VARCHAR(20),
    hub_key INT REFERENCES dim_hubs(hub_key),
    weather_key INT REFERENCES dim_weather(weather_key)
);

-- ------------------------------------------------------------------------------
-- STEP 6: ETL TRANSFORMATION & LOAD INTO FACT TABLE
-- ------------------------------------------------------------------------------
-- Mapping the text values in staging to the numeric Foreign Keys in dimensions.
-- This normalizes the data and prepares it for optimal Power BI performance.

INSERT INTO fact_deliveries (
    order_id, 
    order_timestamp, 
    cart_value_inr, 
    delivery_time_mins, 
    delivery_status, 
    hub_key, 
    weather_key
)
SELECT 
    s.order_id, 
    s.order_timestamp, 
    s.cart_value_inr, 
    s.delivery_time_mins, 
    s.delivery_status, 
    h.hub_key, 
    w.weather_key
FROM staging_deliveries s
JOIN dim_hubs h ON s.dark_store_name = h.hub_name
JOIN dim_weather w ON s.weather_condition = w.condition_type;

-- ------------------------------------------------------------------------------
-- STEP 7: DATA VALIDATION & QUALITY CHECK
-- ------------------------------------------------------------------------------
-- Verifying the 50,000 row split and tracking 'Revenue at Risk'.
-- Confirms the preservation of 1,000 'System Error' rows.

SELECT 
    delivery_status, 
    COUNT(*) as order_count, 
    SUM(cart_value_inr) as total_revenue
FROM fact_deliveries
GROUP BY delivery_status;