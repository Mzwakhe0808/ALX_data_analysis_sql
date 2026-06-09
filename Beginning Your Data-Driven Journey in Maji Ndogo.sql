/* ==========================================================
   Author      : Mzwakhe Sefo
   Project     : ALX Data Analytics Project
   Description : Exploratory queries and data cleaning on the
                 Maji Ndogo water services dataset.
   ========================================================== */

-- List all tables in the current database
SHOW TABLES;

-- Preview the structure of the employee table (columns, types, nullability)
DESCRIBE 
	employee;

-- Preview all water source records
SELECT *
FROM 
	water_source;

-- Identify visits with unusually long queue times (over 500 minutes)
-- These may indicate data quality issues or severely underserved sources
SELECT *
FROM 
	visits
WHERE 
	time_in_queue > 500;

-- Look up the water sources linked to those long-queue visits
SELECT *
FROM water_source
WHERE source_id IN ('AkKi00881224', 'SoRu37635224', 'SoRu36096224',
                    'AkRu05234224', 'HaZa21742224');

-- Find records where surveyors rated quality 10 but visited more than once
-- A perfect score should not require a second visit these are likely errors
SELECT *
FROM 
	water_quality
WHERE 
	subjective_quality_score = 10 AND visit_count = 2;

-- Preview the well_pollution table structure and contents
SELECT *
FROM well_pollution
LIMIT 5;
SELECT description FROM well_pollution;

-- Find records incorrectly prefixed with 'Clean' that are actually contaminated
-- e.g. 'Clean Bacteria: E. coli' should be 'Bacteria: E. coli'
SELECT *
FROM well_pollution
WHERE  description LIKE 'Clean%'
		AND description <> 'Clean';
        
SELECT *
FROM well_pollution
WHERE description LIKE 'Clean_%';

-- Fix corrupted descriptions: strip the erroneous 'Clean ' prefix
SET SQL_SAFE_UPDATES = 0;
UPDATE well_pollution
SET description = 'Bacteria: E. coli'
WHERE description = 'Clean Bacteria: E. coli';
	
UPDATE well_pollution
SET description ='Bacteria: Giardia Lamblia'
WHERE description = 'Clean Bacteria: Giardia Lamblia';
SET SQL_SAFE_UPDATES = 1;

-- Create a backup before making further structural changes
CREATE TABLE
md_water_services.well_pollution_copy
AS (
SELECT
*
FROM
md_water_services.well_pollution
);

-- Flag wells as biologically contaminated where biological score exceeds safe threshold
-- Only updates records currently marked Clean to avoid overwriting existing flags
UPDATE well_pollution
SET	description = 'Contaminated: Biological'
WHERE biological > 0.01 AND results = 'Clean';

-- Drop backup to keep the schema clean
DROP TABLE well_pollution_copy;

