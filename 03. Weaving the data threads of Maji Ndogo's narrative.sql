/* ==========================================================
   Author      : Mzwakhe Sefo
   Project     : ALX Data Analytics Project
   Module      : Data Integrity & Fraud Detection
   Description : Integrating the auditor report, linking records
                 and identifying employees with suspicious data
                 entries in the Maji Ndogo dataset.
   ========================================================== */

-- Step 1: Create the auditor_report table
DROP TABLE IF EXISTS md_water_services.auditor_report;
CREATE TABLE md_water_services.auditor_report (
  `location_id` VARCHAR(32),
  `type_of_water_source` VARCHAR(64),
  `true_water_source_score` INT DEFAULT NULL,
  `statements` VARCHAR(255)
);

-- Manually import auditor_report.csv via Table Data Import Wizard after creating the table

-- Step 2: Preview the auditor report
SELECT
    location_id,
    true_water_source_score
FROM md_water_services.auditor_report
LIMIT 5;

-- Step 3: Link auditor report to visits and water_quality to compare scores
SELECT
    auditor_report.location_id AS location_id,
    visits.record_id,
    auditor_report.true_water_source_score AS audit_score,
    water_quality.subjective_quality_score AS surveyor_score
FROM auditor_report
JOIN visits
    ON auditor_report.location_id = visits.location_id
JOIN water_quality
    ON water_quality.record_id = visits.record_id;

-- Step 4: Filter MATCHED scores (1518/1620 = 94% accuracy)
SELECT
    auditor_report.location_id AS location_id,
    visits.record_id,
    auditor_report.true_water_source_score AS audit_score,
    water_quality.subjective_quality_score AS surveyor_score
FROM auditor_report
JOIN visits
    ON auditor_report.location_id = visits.location_id
JOIN water_quality
    ON water_quality.record_id = visits.record_id
WHERE water_quality.subjective_quality_score = auditor_report.true_water_source_score
AND visits.visit_count = 1;

-- Step 5: Filter MISMATCHED scores (102 incorrect records)
SELECT
    auditor_report.location_id AS location_id,
    visits.record_id,
    auditor_report.true_water_source_score AS audit_score,
    water_quality.subjective_quality_score AS surveyor_score
FROM auditor_report
JOIN visits
    ON auditor_report.location_id = visits.location_id
JOIN water_quality
    ON water_quality.record_id = visits.record_id
WHERE water_quality.subjective_quality_score != auditor_report.true_water_source_score
AND visits.visit_count = 1;

-- Step 6: Check if water source types also mismatch (they don't — only scores are wrong)
SELECT
    auditor_report.location_id AS location_id,
    auditor_report.type_of_water_source AS auditor_source,
    water_source.type_of_water_source AS surveyor_source,
    visits.record_id,
    auditor_report.true_water_source_score AS audit_score,
    water_quality.subjective_quality_score AS surveyor_score
FROM auditor_report
JOIN visits
    ON auditor_report.location_id = visits.location_id
JOIN water_quality
    ON water_quality.record_id = visits.record_id
JOIN water_source
    ON water_source.source_id = visits.source_id
WHERE water_quality.subjective_quality_score != auditor_report.true_water_source_score
AND visits.visit_count = 1;
-- The source types match so even though scores are wrong,
-- the integrity of type_of_water_source data is not affected.

-- Step 7: Link employee names to the mismatched records
SELECT
    auditor_report.location_id AS location_id,
    visits.record_id,
    employee.employee_name,
    auditor_report.true_water_source_score AS audit_score,
    water_quality.subjective_quality_score AS surveyor_score
FROM auditor_report
JOIN visits
    ON auditor_report.location_id = visits.location_id
JOIN water_quality
    ON water_quality.record_id = visits.record_id
JOIN employee
    ON employee.assigned_employee_id = visits.assigned_employee_id
WHERE water_quality.subjective_quality_score != auditor_report.true_water_source_score
AND visits.visit_count = 1;

-- Step 8: Create the Incorrect_records VIEW (includes statements)
CREATE VIEW incorrect_records AS (
SELECT
    auditor_report.location_id AS location_id,
    visits.record_id,
    employee.employee_name,
    auditor_report.true_water_source_score AS audit_score,
    water_quality.subjective_quality_score AS surveyor_score,
    auditor_report.statements
FROM auditor_report
JOIN visits
    ON auditor_report.location_id = visits.location_id
JOIN water_quality
    ON water_quality.record_id = visits.record_id
JOIN employee
    ON employee.assigned_employee_id = visits.assigned_employee_id
WHERE water_quality.subjective_quality_score != auditor_report.true_water_source_score
AND visits.visit_count = 1
);

-- Step 9: Preview the view and count mistakes per employee
SELECT * FROM incorrect_records;

SELECT
    employee_name,
    COUNT(employee_name) AS number_of_mistakes
FROM incorrect_records
GROUP BY employee_name;

-- Step 10: Find employees with above-average mistakes (suspect list)
WITH error_count AS (
  -- Counts the number of mistakes each employee made
  SELECT
    employee_name,
    COUNT(employee_name) AS number_of_mistakes
  FROM incorrect_records
  GROUP BY employee_name
),
suspect_list AS (
  -- Filters to employees with above-average mistakes
  SELECT
    employee_name,
    number_of_mistakes
  FROM error_count
  WHERE number_of_mistakes > (SELECT AVG(number_of_mistakes) FROM error_count)
)
SELECT * FROM suspect_list;

-- Step 11: Pull all records from suspects with statements
-- incorrect_records is a view that joins the auditor report to the database
-- for records where the auditor and employee scores differ
WITH error_count AS (
  SELECT
    employee_name,
    COUNT(employee_name) AS number_of_mistakes
  FROM incorrect_records
  GROUP BY employee_name
),
suspect_list AS (
  SELECT
    employee_name,
    number_of_mistakes
  FROM error_count
  WHERE number_of_mistakes > (SELECT AVG(number_of_mistakes) FROM error_count)
)
-- Filters all records where the suspected employees gathered data
SELECT
  employee_name,
  location_id,
  statements
FROM incorrect_records
WHERE employee_name IN (SELECT employee_name FROM suspect_list);

-- Step 12: Filter suspect records mentioning "cash" as evidence of bribery
WITH error_count AS (
  SELECT
    employee_name,
    COUNT(employee_name) AS number_of_mistakes
  FROM incorrect_records
  GROUP BY employee_name
),
suspect_list AS (
  SELECT
    employee_name,
    number_of_mistakes
  FROM error_count
  WHERE number_of_mistakes > (SELECT AVG(number_of_mistakes) FROM error_count)
)
SELECT
  employee_name,
  location_id,
  statements
FROM incorrect_records
WHERE employee_name IN (SELECT employee_name FROM suspect_list)
AND statements LIKE '%cash%';

-- Step 13: Confirm no non-suspects mention "cash" (validates findings)
WITH error_count AS (
  SELECT
    employee_name,
    COUNT(employee_name) AS number_of_mistakes
  FROM incorrect_records
  GROUP BY employee_name
),
suspect_list AS (
  SELECT
    employee_name,
    number_of_mistakes
  FROM error_count
  WHERE number_of_mistakes > (SELECT AVG(number_of_mistakes) FROM error_count)
)
SELECT
  employee_name,
  location_id,
  statements
FROM incorrect_records
WHERE employee_name NOT IN (SELECT employee_name FROM suspect_list)
AND statements LIKE '%cash%';