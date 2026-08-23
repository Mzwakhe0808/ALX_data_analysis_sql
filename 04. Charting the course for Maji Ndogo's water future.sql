/* ==========================================================
   Author      : Mzwakhe Sefo
   Project     : ALX Data Analytics Project
   Module      : Data Integrity & Fraud Detection
   Description : Integrating the auditor report, linking records
                 and identifying employees with suspicious data
                 entries in the Maji Ndogo dataset.
   ========================================================== */

-- ==========================================================
-- 1. BUILD THE COMBINED ANALYSIS DATASET
-- ==========================================================
   
SELECT
    l.province_name,
    l.town_name,
    ws.type_of_water_source,
    l.location_type,
    ws.number_of_people_served,
    v.time_in_queue
FROM visits v
JOIN location l
    ON v.location_id = l.location_id
JOIN water_source ws
    ON v.source_id = ws.source_id
WHERE v.visit_count = 1;


CREATE VIEW combined_analysis_table AS
-- This table assembles data from different tables into one to simplify analysis
SELECT
	water_source.type_of_water_source AS source_type,
	location.town_name,
	location.province_name,
	location.location_type,
	water_source.number_of_people_served AS people_served,
	visits.time_in_queue,
	well_pollution.results
FROM
	visits 
	LEFT JOIN
		well_pollution
	ON well_pollution.source_id = visits.source_id
	INNER JOIN
		location
	ON location.location_id = visits.location_id
	INNER JOIN
		water_source
	ON water_source.source_id = visits.source_id
WHERE
visits.visit_count = 1;

-- ==========================================================
-- 2. ANALYSE WATER ACCESS BY PROVINCE
-- ==========================================================

WITH province_totals AS (-- This CTE calculates the population of each province
		SELECT
			province_name,
			SUM(people_served) AS total_ppl_serv
		FROM
			combined_analysis_table
		GROUP BY
			province_name
	)
    SELECT
		ct.province_name,
		-- These case statements create columns for each type of source.
		-- The results are aggregated and percentages are calculated
		ROUND((SUM(CASE WHEN source_type = 'river'
			THEN people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS river,
		ROUND((SUM(CASE WHEN source_type = 'shared_tap'
			THEN people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS shared_tap,
		ROUND((SUM(CASE WHEN source_type = 'tap_in_home'
			THEN people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS tap_in_home,
		ROUND((SUM(CASE WHEN source_type = 'tap_in_home_broken'
			THEN people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS tap_in_home_broken,
		ROUND((SUM(CASE WHEN source_type = 'well'
			THEN people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS well
FROM
	combined_analysis_table ct
JOIN
	province_totals pt 
ON ct.province_name = pt.province_name
GROUP BY
	ct.province_name
ORDER BY
	ct.province_name;

-- province_totals is a CTE that calculates the sum of all the people surveyed grouped by province.
WITH province_totals AS (-- This CTE calculates the population of each province
		SELECT
			province_name,
			SUM(people_served) AS total_ppl_serv
		FROM
			combined_analysis_table
		GROUP BY
			province_name
	)
SELECT
*
FROM
province_totals;

-- ==========================================================
-- 3. ANALYSE WATER ACCESS BY TOWN
-- ==========================================================

WITH town_totals AS (-- This CTE calculates the population of each town
--  Since there are two Harare towns, we have to group by province_name and town_name
	SELECT 
		province_name, town_name, SUM(people_served) AS total_ppl_serv
	FROM 
		combined_analysis_table
	GROUP BY 
		province_name,town_name
)
SELECT
	ct.province_name,
	ct.town_name,
	ROUND((SUM(CASE WHEN source_type = 'river'
		THEN people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv), 0) AS river,
	ROUND((SUM(CASE WHEN source_type = 'shared_tap'
		THEN people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv), 0) AS shared_tap,
	ROUND((SUM(CASE WHEN source_type = 'tap_in_home'
		THEN people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv), 0) AS tap_in_home,
	ROUND((SUM(CASE WHEN source_type = 'tap_in_home_broken'
		THEN people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv), 0) AS tap_in_home_broken,
	ROUND((SUM(CASE WHEN source_type = 'well'
		THEN people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv), 0) AS well
FROM
combined_analysis_table ct
JOIN 			-- Since the town names are not unique, we have to join on a composite key
	town_totals tt 
ON 
	ct.province_name = tt.province_name 
	AND ct.town_name = tt.town_name
GROUP BY 		-- We group by province first, then by town.
	ct.province_name,
	ct.town_name
ORDER BY
	ct.town_name;
    
-- ==========================================================
-- 4. CREATE A REUSABLE TOWN-LEVEL SUMMARY
-- ==========================================================

-- The town-level calculation is more complex, so I store the
-- result temporarily. This makes it easier to run additional
-- analysis without repeating the full aggregation.

CREATE TEMPORARY TABLE town_aggregated_water_access   
WITH town_totals AS (-- This CTE calculates the population of each town
--  Since there are two Harare towns, we have to group by province_name and town_name
	SELECT 
		province_name, town_name, SUM(people_served) AS total_ppl_serv
	FROM 
		combined_analysis_table
	GROUP BY 
		province_name,town_name
)
SELECT
	ct.province_name,
	ct.town_name,
	ROUND((SUM(CASE WHEN source_type = 'river'
		THEN people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv), 0) AS river,
	ROUND((SUM(CASE WHEN source_type = 'shared_tap'
		THEN people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv), 0) AS shared_tap,
	ROUND((SUM(CASE WHEN source_type = 'tap_in_home'
		THEN people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv), 0) AS tap_in_home,
	ROUND((SUM(CASE WHEN source_type = 'tap_in_home_broken'
		THEN people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv), 0) AS tap_in_home_broken,
	ROUND((SUM(CASE WHEN source_type = 'well'
		THEN people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv), 0) AS well
FROM
combined_analysis_table ct
JOIN 			-- Since the town names are not unique, we have to join on a composite key
	town_totals tt 
ON 
	ct.province_name = tt.province_name 
	AND ct.town_name = tt.town_name
GROUP BY 		
	ct.province_name,
	ct.town_name
ORDER BY
	ct.town_name; 
    
-- ==========================================================
-- 5. IDENTIFY PRIORITY AREAS
-- ==========================================================

-- Sorting by river usage highlights towns where large numbers
-- of people are relying on river water
    
SELECT
*
FROM town_aggregated_water_access
ORDER BY
	river DESC;
    
-- People are drinking river water in Sokoto.

-- which town has the highest ratio of people who have taps, but have no running water?
SELECT
	province_name,
	town_name,
	ROUND(tap_in_home_broken / (tap_in_home_broken + tap_in_home) * 100,0) AS Pct_broken_taps
FROM 
	town_aggregated_water_access;
-- We can see that Amina has infrastructure installed, but almost none of it is working, and only the capital city,
-- Dahabu's water infrastructure works.    



-- ==========================================================
-- 6. CREATE THE PROJECT TRACKING TABLE
-- ==========================================================

-- The analysis identifies the problems, but the goal is to turn
-- those findings into something engineers can actually use.
-- Create a project table containing the location,
-- water source, recommended improvement, and project status

CREATE TABLE project_progress (
	Project_id SERIAL PRIMARY KEY,
	/* Project_id −− Unique key for sources in case we visit the same
	source more than once in the future.
	*/
	source_id VARCHAR(20) NOT NULL REFERENCES water_source(source_id) ON DELETE CASCADE ON UPDATE CASCADE,
	/* source_id −− Each of the sources.
	*/
	Address VARCHAR(50), --  Street address
	Town VARCHAR(30),
	Province VARCHAR(30),
	Source_type VARCHAR(50),
	Improvement VARCHAR(50), -- What the engineers should do at that place
	Source_status VARCHAR(50) DEFAULT 'Backlog' CHECK (Source_status IN ('Backlog', 'In progress', 'Complete')),
	/* Source_status −− We want to limit the type of information engineers can give us, so we
	limit Source_status.
	− By DEFAULT all projects are in the "Backlog" which is like a TODO list.
	− CHECK() ensures only those three options will be accepted. This helps to maintain clean data.
	*/
	Date_of_completion DATE, -- Engineers will add this the day the source has been upgraded.
	Comments TEXT -- Engineers can leave comments. We use a TEXT type that has no limit on char length
);


-- ==========================================================
-- 7. BUILD THE PROJECT DATASET
-- ==========================================================

-- Before inserting the final recommendations, I check the
-- information that connects each water source to its location
-- and pollution results.

SELECT
	location.address,
	location.town_name,
	location.province_name,
	water_source.source_id,
	water_source.type_of_water_source,
	well_pollution.results
FROM
	water_source
LEFT JOIN
	well_pollution ON water_source.source_id = well_pollution.source_id
INNER JOIN
	visits ON water_source.source_id = visits.source_id
INNER JOIN
	location ON location.location_id = visits.location_id 
WHERE visits.visit_count = 1;

-- ==========================================================
-- 8. TURN THE FINDINGS INTO RECOMMENDED ACTIONS
-- ==========================================================

INSERT INTO project_progress (
    source_id,
    Address,
    Town,
    Province,
    Source_type,
    Improvement
)
SELECT
    w.source_id,
    l.address,
    l.town_name,
    l.province_name,
    w.type_of_water_source,

	CASE
		-- Chemical contamination requires RO filtration.
		WHEN wp.results = 'Contaminated: Chemical'
		THEN 'Install RO filters'
		
		-- Biological contamination requires UV treatment
		-- together with RO filtration
		WHEN wp.results = 'Contaminated: Biological'
		THEN 'Install RO filters and UV filters'
		
		-- Communities relying on rivers need a safer and more
		-- permanent water source
		WHEN w.type_of_water_source = 'river'
		THEN 'Drill wells'

		-- Long queues indicate that additional taps are needed.
		-- One tap is planned for each 30 minutes of queue time.
		WHEN w.type_of_water_source = 'shared_tap' AND v.time_in_queue >= 30
		THEN CONCAT('Install ', FLOOR(v.time_in_queue / 30), ' taps nearby.')

		-- Existing household infrastructure should first be
		-- investigated to determine what needs to be repaired.
		WHEN w.type_of_water_source = 'tap_in_home_broken'
		THEN 'Diagnose local infrastructure' 
		ELSE NULL
	END AS Improvement
FROM
    water_source AS w
LEFT JOIN well_pollution AS wp
    ON w.source_id = wp.source_id
INNER JOIN visits AS v
    ON w.source_id = v.source_id
INNER JOIN location AS l
    ON l.location_id = v.location_id
WHERE v.visit_count = 1
AND (
    wp.results IN (
        'Contaminated: Chemical',
        'Contaminated: Biological'
    )
    OR w.type_of_water_source IN (
        'tap_in_home_broken',
        'river'
    )
    OR (
        w.type_of_water_source = 'shared_tap'
        AND v.time_in_queue >= 30
    )
);
-- WHERE v.visit_count = 1
--     AND ((wp.results != 'Clean' OR wp.results IS NULL)
--     OR w.type_of_water_source IN ('tap_in_home_broken', 'river')
--     OR (w.type_of_water_source = 'shared_tap' AND v.time_in_queue >= 30));
    
-- ==========================================================
-- 9. FINAL CHECK: ANALYSIS TO ACTION
-- ==========================================================

SELECT
    Project_id,
    source_id,
    Address,
    Town,
    Province,
    Source_type,
    Improvement,
    Source_status,
    Date_of_completion,
    Comments
FROM Project_progress;
-- ORDER BY Province, Town
WHERE 
Source_type = 'tap_in_home';

SELECT * FROM project_progress WHERE Project_id =! null LIMIT 26000;