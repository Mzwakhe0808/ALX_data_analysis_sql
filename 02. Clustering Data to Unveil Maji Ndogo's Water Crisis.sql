/* ==========================================================
   Author      : Mzwakhe Sefo
   Project     : ALX Data Analytics Project
   Description : Data cleaning, transformation, and preparation
                 for analysis on the Maji Ndogo dataset.
   ========================================================== */


-- ==========================================================
-- SECTION 1: EMPLOYEE DATA CLEANING
-- ==========================================================

-- Generate and assign emails in the format firstname.lastname@ndogowater.gov
SET SQL_SAFE_UPDATES = 0;
 
UPDATE md_water_services.employee
SET email = CONCAT(LOWER(REPLACE(employee_name, ' ', '.')), '@ndogowater.gov');
 
-- Remove leading/trailing whitespace from phone numbers
UPDATE md_water_services.employee
SET phone_number = TRIM(phone_number);
 
SET SQL_SAFE_UPDATES = 1;
 
-- Count surveyors per town
SELECT 
	town_name,
	COUNT(employee_name) AS num_employee
FROM employee
GROUP BY town_name;

-- Identify top 3 surveyors by visit count  
SELECT 
	assigned_employee_id,
    SUM(visit_count) AS number_of_visits
FROM visits
GROUP BY assigned_employee_id
ORDER BY 
	number_of_visits desc
LIMIT 3;
-- Note assigned_employee_id and retrieve their details 
SELECT
	*
FROM employee
WHERE assigned_employee_id IN (1, 30 , 34);

-- ==========================================================
-- SECTION 2: LOCATION ANALYSIS
-- ==========================================================
 
-- Record count per town, grouped by province
-- Insight: Shows geographic distribution of surveyed locations
-- 
SELECT
    province_name,
    town_name,
    COUNT(*) AS records_per_town
FROM location
GROUP BY province_name, town_name
ORDER BY province_name ASC, records_per_town DESC;

-- Distribution of rural vs. urban sources
-- Insight: ~60% of water sources are in rural communities
SELECT 
	COUNT(*) AS num_sources,
	location_type
FROM location
GROUP BY location_type;

SELECT (COUNT(*) / (SELECT COUNT(*) FROM location)) * 100 as percentage_rural
FROM location
WHERE location_type = 'Rural';
    
-- ==========================================================
-- SECTION 3: WATER SOURCE ANALYSIS
-- ==========================================================

-- Number of people survey in total?
SELECT 
	COUNT(*) AS total_survey
FROM water_source;

-- How many wells, taps, and rivers are there?
SELECT
	type_of_water_source,
	COUNT(number_of_people_served) AS number_of_sources
FROM water_source
GROUP BY 
	type_of_water_source
ORDER BY
    type_of_water_source DESC;
    
-- Average number of people served by each water source
SELECT
	type_of_water_source,
	ROUND(AVG(number_of_people_served)) AS avg_per_source
FROM water_source
GROUP BY 
	type_of_water_source
ORDER BY
    avg_per_source DESC;
-- =====================================================================
-- 1 tap_in_home actually represents 644 ÷ 6 = ± 100 taps.
-- =====================================================================
-- How many people are getting water from each type of source?
SELECT 
	type_of_water_source,
	SUM(number_of_people_served) AS population_served
FROM water_source
GROUP BY 
	type_of_water_source
ORDER BY
	population_served DESC;
-- Calculate the percentages of people served by each type of source.
WITH total AS (
    SELECT SUM(number_of_people_served) AS grand_total
    FROM water_source
)
SELECT 
    type_of_water_source,
    ROUND(SUM(number_of_people_served) * 100 / total.grand_total, 0) AS pct_people_served
FROM water_source, total
GROUP BY 
    type_of_water_source, total.grand_total
ORDER BY 
    pct_people_served DESC;
    
-- ==========================================================
-- SECTION 4: PRIORITISATION & RANKING
-- ==========================================================

-- Rank Water Sources by Total Population Served
SELECT 
    type_of_water_source,
    SUM(number_of_people_served) AS people_served,
    RANK() OVER (ORDER BY SUM(number_of_people_served) DESC) AS rank_by_population
FROM water_source
WHERE type_of_water_source != 'tap_in_home'
GROUP BY 
    type_of_water_source
ORDER BY 
    rank_by_population;
-- Consider Output Format
SELECT 
    type_of_water_source,
    source_id,
    number_of_people_served,
    RANK() OVER (
        PARTITION BY type_of_water_source 
        ORDER BY number_of_people_served DESC
    ) AS priority_rank
FROM water_source
WHERE type_of_water_source != 'tap_in_home'
ORDER BY 
    number_of_people_served DESC;
    
-- ==========================================================
-- SECTION 5: QUEUE TIME ANALYSIS
-- ==========================================================

-- Average queue time for each day of the week
SELECT
    DAYNAME(time_of_record) AS day_of_week,
    ROUND(AVG(time_in_queue), 0) AS avg_queue_time
FROM
    visits
WHERE
    time_in_queue > 0
GROUP BY
    day_of_week;

-- average queue time for each hour of the day
SELECT
    HOUR(time_of_record) AS hour_of_day,
    ROUND(AVG(time_in_queue), 0) AS avg_queue_time
FROM
    visits
WHERE
    time_in_queue > 0
GROUP BY
    hour_of_day;
    
-- Pivoting the data for all days
SELECT
    TIME_FORMAT(TIME(time_of_record), '%H:00') AS hour_of_day,
    -- Sunday
    ROUND(AVG(
        CASE
            WHEN DAYNAME(time_of_record) = 'Sunday' THEN time_in_queue
            ELSE NULL
        END
    ), 0) AS Sunday,
    -- Monday
    ROUND(AVG(
        CASE
            WHEN DAYNAME(time_of_record) = 'Monday' THEN time_in_queue
            ELSE NULL
        END
    ), 0) AS Monday,
    -- Tuesday
    ROUND(AVG(
        CASE
            WHEN DAYNAME(time_of_record) = 'Tuesday' THEN time_in_queue
            ELSE NULL
        END
    ), 0) AS Tuesday,
    -- Wednesday
    ROUND(AVG(
        CASE
            WHEN DAYNAME(time_of_record) = 'Wednesday' THEN time_in_queue
            ELSE NULL
        END
    ), 0) AS Wednesday,
    -- Thursday
    ROUND(AVG(
        CASE
            WHEN DAYNAME(time_of_record) = 'Thursday' THEN time_in_queue
            ELSE NULL
        END
    ), 0) AS Thursday,
    -- Friday
    ROUND(AVG(
        CASE
            WHEN DAYNAME(time_of_record) = 'Friday' THEN time_in_queue
            ELSE NULL
        END
    ), 0) AS Friday,
    -- Saturday
    ROUND(AVG(
        CASE
            WHEN DAYNAME(time_of_record) = 'Saturday' THEN time_in_queue
            ELSE NULL
        END
    ), 0) AS Saturday
FROM
    visits
WHERE
    time_in_queue != 0
GROUP BY
    hour_of_day
ORDER BY
    hour_of_day;
    
-- =================================================
-- MORE KEY INSIGTHS
-- =================================================

-- Shared taps usage and average users per tap
SELECT
    COUNT(*) AS shared_tap_users,
    AVG(number_of_people_served) AS avg_users_per_tap
FROM water_source
WHERE type_of_water_source = 'shared_tap';

-- population using shared taps, wells, infrastructure, non-functional infrastructure in their homes.
SELECT 
  CONCAT(ROUND(SUM(number_of_people_served) / 1e6, 2), ' million') AS total_population,
  CONCAT(ROUND(SUM(CASE WHEN type_of_water_source = 'shared_tap' THEN number_of_people_served ELSE 0 END) / 1e6, 2), ' million') AS shared_tap_users,
  CONCAT(ROUND(SUM(CASE WHEN type_of_water_source = 'well' THEN number_of_people_served ELSE 0 END) / 1e6, 2), ' million') AS well_users,
  CONCAT(ROUND(SUM(CASE WHEN type_of_water_source = 'tap_in_home' THEN number_of_people_served ELSE 0 END) / 1e6, 2), ' million') AS infrastructure_users,
  CONCAT(ROUND(SUM(CASE WHEN type_of_water_source = 'tap_in_home_broken' THEN number_of_people_served ELSE 0 END) / 1e6, 2), ' million') AS non_functional_infrastructure_users
FROM water_source;