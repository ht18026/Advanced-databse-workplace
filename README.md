# Advanced Database Projects: Data Warehouse & Spatial Analysis

This repository contains two comprehensive SQL-based assignments demonstrating advanced database concepts, data warehousing, and spatial data analysis capabilities.

## Overview

This project showcases expertise in:
- **Data Warehousing** (Assignment 2): Dimensional modeling, ETL processes, and business intelligence
- **Spatial Data Analysis** (Assignment 3): Geographic information systems (GIS), PostGIS, and public transport data analysis

---

## Assignment 2: Data Warehouse Implementation

### Objective
Design and implement a star schema data warehouse for an equipment sales and rental business (MONEQUIP), enabling analytical queries for business intelligence.

### Technologies
- **Database**: Oracle SQL
- **Schema Type**: Star Schema (Fact and Dimension Tables)

### Project Structure

#### Files
- `A2_data_cleaning.sql` - Data quality assurance and cleaning operations
- `A2_data_warehouse.sql` - Dimensional model implementation and ETL
- `A2_data_analysis.sql` - Business intelligence queries and analytics

#### Data Warehouse Components

**Dimension Tables:**
- `DIM_MONTH` - Temporal dimension with year and season attributes
- `DIM_CATEGORY` - Equipment category classifications
- `DIM_BRANCH` - Company branch locations
- `DIM_CUSTOMER_TYPE` - Customer segmentation (Individual/Business)
- `DIM_PRICE_SCALE` - Sales price classifications (LOW/MED/HIGH)

**Fact Tables:**
- `FACT_SALES_AGG` - Aggregated sales transactions with metrics (revenue, units sold, transaction count)
- `FACT_HIRE_AGG` - Aggregated equipment rental transactions with metrics (revenue, units hired, transaction count)

#### Key Features
1. **Data Cleaning**: Handles duplicates, NULL values, referential integrity, and business rule validation
2. **ETL Pipeline**: Transforms operational data into analytical star schema
3. **Business Analytics**: Supports queries for seasonal trends, branch performance, customer segmentation, and revenue analysis
4. **Sample Queries Included**:
   - Total sales revenue by period
   - Equipment units sold/hired by season
   - Revenue analysis by branch, category, and customer type
   - Average transaction values by segment

---

## Assignment 3: Spatial Data Analysis

### Objective
Analyze public transport accessibility in Greater Melbourne using PostGIS spatial database capabilities and GTFS (General Transit Feed Specification) data.

### Technologies
- **Database**: PostgreSQL with PostGIS extension
- **Data Sources**:
  - Public Transport Victoria (PTV) GTFS feeds
  - Australian Bureau of Statistics (ABS) Mesh Block data (2021)
  - Local Government Area (LGA) and Suburb (SAL) boundaries

### Project Structure

#### Files
- `A3-task1.sql` - Database schema creation and GTFS data import
- `A3-task2.sql` - Spatial data processing and bus stop analysis
- `A3-task3.sql` - Advanced spatial analysis and accessibility metrics

#### Database Schema

**GTFS Tables:**
- `agency` - Transit agency information
- `routes` - Public transport routes
- `trips` - Individual service trips
- `stops` - Physical stop locations with geometry
- `stop_times` - Schedule information
- `shapes` - Route path geometries
- `calendar` / `calendar_dates` - Service calendars

**Spatial Reference Tables:**
- `mb_2021` - Mesh Block boundaries (smallest geographic unit)
- `lga_2021` - Local Government Area boundaries
- `sal_2021` - Suburb and Locality boundaries

#### Key Features

1. **Spatial Data Processing**:
   - Coordinate system transformation (WGS84 to GDA2020)
   - Point geometry creation from latitude/longitude
   - Spatial indexing for performance optimization

2. **Bus Stop Analysis**:
   - Filter and map all bus stops in Greater Melbourne
   - Route identification and vehicle type classification
   - Spatial intersection with administrative boundaries

3. **Accessibility Analysis**:
   - Calculate public transport access density by area
   - Analyze stop distribution in industrial and employment zones
   - Stop density metrics (stops per square kilometer)

4. **Spatial Operations**:
   - `ST_Intersects` - Identify points within polygons
   - `ST_Transform` - Convert coordinate systems
   - `ST_MakePoint` - Create point geometries
   - GIST spatial indexing for query optimization

---

## Technical Highlights

### Data Quality & Integrity
- Comprehensive data cleaning procedures
- Referential integrity enforcement
- NULL value handling and validation
- Duplicate detection and resolution
- Business rule validation (e.g., date ranges, calculated fields)

### Performance Optimization
- Strategic indexing on foreign keys and spatial columns
- Aggregated fact tables for fast analytical queries
- Spatial indexes (GIST) for geographic operations
- View materialization for complex calculations

### Analytical Capabilities
- Multi-dimensional analysis (time, location, category, customer type)
- Seasonal trend analysis
- Geographic accessibility metrics
- Customer segmentation analytics
- Revenue and performance tracking

---

## Database Requirements

### Assignment 2 (Oracle)
- Oracle Database 11g or higher
- SQL*Plus or similar client

### Assignment 3 (PostgreSQL)
- PostgreSQL 12 or higher
- PostGIS 3.0 or higher extension
- GTFS data files (agency, routes, trips, stops, stop_times, shapes, calendar)
- ABS Mesh Block 2021 shapefiles

---

## Execution Instructions

### Assignment 2
```sql
-- Execute in order:
@A2_data_cleaning.sql
@A2_data_warehouse.sql
@A2_data_analysis.sql
```

### Assignment 3
```sql
-- Set search path and execute:
SET search_path TO ptv, public;
\i A3-task1.sql
\i A3-task2.sql
\i A3-task3.sql
```

---

## Data Sources

- **Assignment 2**: MONEQUIP operational database (equipment sales and rental)
- **Assignment 3**:
  - Public Transport Victoria GTFS feeds
  - Australian Bureau of Statistics 2021 Census boundaries
  - Mesh Block, LGA, and SAL geographic datasets

---

## Project Outcomes

This project demonstrates:
- Proficiency in dimensional modeling and data warehousing
- Advanced SQL capabilities across multiple database platforms
- Spatial data analysis and GIS operations
- Data quality management and ETL processes
- Business intelligence and analytical query design
- Real-world problem solving with geographic and temporal data

---

## Author
Developed as part of Advanced Database coursework demonstrating enterprise-level database design and analysis capabilities.
