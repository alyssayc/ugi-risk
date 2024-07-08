/*
* Encounters. Determines the index time for temporal data. 
*/

DROP TABLE IF EXISTS #Encounters;
SELECT
	e.visit_occurrence_id as visit_id,
	e.person_id as pt_id,
	e.xtn_epic_encounter_number,
	e.etl_epic_encounter_key,
	e.xtn_visit_type_source_concept_name as encounter_type,
	c.xtn_parent_location_name as care_site,
	e.visit_start_date,
	e.visit_end_date,
	DATEADD(month, -6, e.visit_start_date) AS visit_start_date_minus_6mo,
	DATEADD(month, -9, e.visit_start_date) AS visit_start_date_minus_9mo,
	DATEADD(month, -12, e.visit_start_date) AS visit_start_date_minus_12mo,
	DATEADD(month, -18, e.visit_start_date) AS visit_start_date_minus_18mo
INTO #Encounters 
FROM omop.cdm_phi.visit_occurrence e
LEFT JOIN omop.cdm_phi.care_site c ON e.care_site_id = c.care_site_id 
WHERE xtn_visit_type_source_concept_name IN ('Telehealth Visit', 'Outpatient Visit', 'Hospital Outpatient Visit', 'Inpatient Hospitalization', 'Inpatient Hospitalization from ED Visit', 'ED Visit')
-- AND visit_start_date BETWEEN '1974-06-01' AND '2023-03-30' 
AND visit_start_date BETWEEN '1974-06-01' AND '2005-06-01' -- change me 

/*
 * Demographics. Nontemporal patient data 
 */

DROP TABLE IF EXISTS #Demographics;
SELECT
	person_id as pt_id,
	gender_c.concept_name as sex,
	DATEFROMPARTS(year_of_birth, month_of_birth, day_of_birth) as dob,
	race_c.concept_name as race,
	ethnicity_c.concept_name as ethnicity,
	xtn_preferred_language_source_concept_name as preferred_language,
	p.xtn_patient_epic_mrn as mrn
INTO #Demographics
FROM omop.cdm_phi.person p 
INNER JOIN omop.cdm_phi.concept gender_c ON gender_c.concept_id = p.gender_concept_id 
INNER JOIN omop.cdm_phi.concept race_c ON race_c.concept_id = p.race_concept_id
INNER JOIN omop.cdm_phi.concept ethnicity_c ON ethnicity_c.concept_id = p.ethnicity_concept_id 
WHERE person_id IN (SELECT DISTINCT pt_id FROM #Encounters)

/*
 * Measurement tables 
 */

DROP TABLE IF EXISTS #BMI;
SELECT 
	person_id as pt_id,
	measurement_concept_id as bmi_id,
	measurement_source_value as bmi_textid,
	measurement_date as bmi_date,
	value_as_number as bmi_num,
	value_source_value as bmi_value,
	unit_concept_code as bmi_unit
INTO #BMI
FROM omop.cdm_phi.measurement
WHERE measurement_concept_id = 3038553
AND measurement_date BETWEEN '1973-02-01' AND '2005-07-01' -- restrict to -15 months from encounter date; change me 
AND person_id IN (SELECT DISTINCT pt_id FROM #Demographics)

-- Includes blood gas hemoglobins
DROP TABLE IF EXISTS #Hgb_all;
SELECT 
	person_id as pt_id,
	measurement_concept_id as hgball_id,
	measurement_source_value as hgball_textid,
	measurement_date as hgball_date,
	value_as_number as hgball_num,
	value_source_value as hgball_value,
	unit_concept_code as hgball_unit
INTO #Hgb_all
FROM omop.cdm_phi.measurement
WHERE measurement_concept_id IN (1616317, 3000963, 3004119, 3006239, 3002173, 46235392)
AND measurement_date BETWEEN '1973-02-01' AND '2005-07-01' -- restrict to -15 months from encounter date; change me 
AND person_id IN (SELECT DISTINCT pt_id FROM #Demographics)

-- Excludes blood gas hemoglobins
DROP TABLE IF EXISTS #Hgb;
SELECT 
	person_id as pt_id,
	measurement_concept_id as hgb_id,
	measurement_source_value as hgb_textid,
	measurement_date as hgb_date,
	value_as_number as hgb_num,
	value_source_value as hgb_value,
	unit_concept_code as hgb_unit
INTO #Hgb
FROM omop.cdm_phi.measurement
WHERE measurement_concept_id IN (3000963, 3006239)
AND measurement_date BETWEEN '1973-02-01' AND '2005-07-01' -- restrict to -15 months from encounter date; change me 
AND person_id IN (SELECT DISTINCT pt_id FROM #Demographics)

DROP TABLE IF EXISTS #Mcv;
SELECT 
	person_id as pt_id,
	measurement_concept_id as mcv_id,
	measurement_source_value as mcv_textid,
	measurement_date as mcv_date,
	value_as_number as mcv_num,
	value_source_value as mcv_value,
	unit_concept_code as mcv_unit
INTO #Mcv
FROM omop.cdm_phi.measurement
WHERE measurement_concept_id IN (3023599, 3024731)
AND measurement_date BETWEEN '1973-02-01' AND '2005-07-01' -- restrict to -15 months from encounter date; change me 
AND person_id IN (SELECT DISTINCT pt_id FROM #Demographics)

DROP TABLE IF EXISTS #Potassium;
SELECT 
	person_id as pt_id,
	measurement_concept_id as potassium_id,
	measurement_source_value as potassium_textid,
	measurement_date as potassium_date,
	value_as_number as potassium_num,
	value_source_value as potassium_value,
	unit_concept_code as potassium_unit
INTO #Potassium
FROM omop.cdm_phi.measurement
WHERE measurement_concept_id IN (3023103, 3043409, 3041354, 3005456)
AND measurement_date BETWEEN '1973-02-01' AND '2005-07-01' -- restrict to -15 months from encounter date; change me 
AND person_id IN (SELECT DISTINCT pt_id FROM #Demographics)

DROP TABLE IF EXISTS #Magnesium;
SELECT 
	person_id as pt_id,
	measurement_concept_id as magnesium_id,
	measurement_source_value as magnesium_textid,
	measurement_date as magnesium_date,
	value_as_number as magnesium_num,
	value_source_value as magnesium_value,
	unit_concept_code as magnesium_unit
INTO #Magnesium
FROM omop.cdm_phi.measurement
WHERE measurement_concept_id IN (3001420, 3006916, 3021770)
AND measurement_date BETWEEN '1973-02-01' AND '2005-07-01' -- restrict to -15 months from encounter date; change me 
AND person_id IN (SELECT DISTINCT pt_id FROM #Demographics)

DROP TABLE IF EXISTS #Calcium;
SELECT 
	person_id as pt_id,
	measurement_concept_id as calcium_id,
	measurement_source_value as calcium_textid,
	measurement_date as calcium_date,
	value_as_number as calcium_num,
	value_source_value as calcium_value,
	unit_concept_code as calcium_unit
INTO #Calcium
FROM omop.cdm_phi.measurement
WHERE measurement_concept_id IN (3006906)
AND measurement_date BETWEEN '1973-02-01' AND '2005-07-01' -- restrict to -15 months from encounter date; change me 
AND person_id IN (SELECT DISTINCT pt_id FROM #Demographics)


DROP TABLE IF EXISTS #Phosphate;
SELECT 
	person_id as pt_id,
	measurement_concept_id as phosphate_id,
	measurement_source_value as phosphate_textid,
	measurement_date as phosphate_date,
	value_as_number as phosphate_num,
	value_source_value as phosphate_value,
	unit_concept_code as phosphate_unit
INTO #Phosphate
FROM omop.cdm_phi.measurement
WHERE measurement_concept_id IN (3011904)
AND measurement_date BETWEEN '1973-02-01' AND '2005-07-01' -- restrict to -15 months from encounter date; change me 
AND person_id IN (SELECT DISTINCT pt_id FROM #Demographics)


DROP TABLE IF EXISTS #Triglycerides;
SELECT 
	person_id as pt_id,
	measurement_concept_id as triglycerides_id,
	measurement_source_value as triglycerides_textid,
	measurement_date as triglycerides_date,
	value_as_number as triglycerides_num,
	value_source_value as triglycerides_value,
	unit_concept_code as triglycerides_unit
INTO #Triglycerides
FROM omop.cdm_phi.measurement
WHERE measurement_concept_id IN (3022192, 36660413)
AND measurement_date BETWEEN '1973-02-01' AND '2005-07-01' -- restrict to -15 months from encounter date; change me 
AND person_id IN (SELECT DISTINCT pt_id FROM #Demographics)


DROP TABLE IF EXISTS #LDL;
SELECT 
	person_id as pt_id,
	measurement_concept_id as LDL_id,
	measurement_source_value as LDL_textid,
	measurement_date as LDL_date,
	value_as_number as LDL_num,
	value_source_value as LDL_value,
	unit_concept_code as LDL_unit
INTO #LDL
FROM omop.cdm_phi.measurement
WHERE measurement_concept_id IN (3028288, 3009966, 3028437, 3007352)
AND measurement_date BETWEEN '1973-02-01' AND '2005-07-01' -- restrict to -15 months from encounter date; change me 
AND person_id IN (SELECT DISTINCT pt_id FROM #Demographics)


DROP TABLE IF EXISTS #Hgba1c;
SELECT 
	person_id as pt_id,
	measurement_concept_id as hgba1c_id,
	measurement_source_value as hgba1c_textid,
	measurement_date as hgba1c_date,
	value_as_number as hgba1c_num,
	value_source_value as hgba1c_value,
	unit_concept_code as hgba1c_unit
INTO #Hgba1c
FROM omop.cdm_phi.measurement
WHERE measurement_concept_id IN (3004410)
AND measurement_date BETWEEN '1973-02-01' AND '2005-07-01' -- restrict to -15 months from encounter date; change me 
AND person_id IN (SELECT DISTINCT pt_id FROM #Demographics)


DROP TABLE IF EXISTS #Hpylori_all;
SELECT 
	person_id as pt_id,
	measurement_concept_id as hpylori_id,
	measurement_source_value as hpylori_textid,
	measurement_date as hpylori_date,
	value_as_number as hpylori_num,
	value_source_value as hpylori_value,
	unit_concept_code as hpylori_unit,
	range_high as hpylori_range_high,
	range_low as hpylori_range_low,
	CASE 
		WHEN value_as_number IS NOT NULL AND value_as_number > range_high THEN 'high'
		WHEN value_as_number IS NOT NULL AND value_as_number <= range_high THEN 'not high'
		WHEN value_as_number IS NOT NULL AND range_high IS NULL THEN 'no range' -- 'H.PYLORI IGG INDEX', 'H. PYLORI IGA', 'H. PYLORI, IGM AB'
		WHEN value_as_number IS NULL AND LOWER(value_source_value) LIKE '%duplicate%' THEN 'error'
		WHEN value_as_number IS NULL AND LOWER(value_source_value) LIKE '%equivocal%' THEN 'not high'
		WHEN value_as_number IS NULL AND LOWER(value_source_value) LIKE '%not sufficient%' THEN 'error'
		WHEN value_as_number IS NULL AND LOWER(value_source_value) LIKE '%not performed%' THEN 'error'
		WHEN value_as_number IS NULL AND LOWER(value_source_value) LIKE '%see%' THEN 'error' -- ie. see below or see note
		WHEN value_as_number IS NULL AND LOWER(value_source_value) LIKE '%no specimen%' THEN 'error'
		WHEN value_as_number IS NULL AND LOWER(value_source_value) LIKE '%incorrect%' THEN 'error'
		WHEN value_as_number IS NULL AND LOWER(value_source_value) LIKE '%inappropriate%' THEN 'error'
		WHEN value_as_number IS NULL AND LOWER(value_source_value) LIKE '%insufficient%' THEN 'error'
		WHEN value_as_number IS NULL AND LOWER(value_source_value) LIKE '%improper%' THEN 'error'
		WHEN value_as_number IS NULL AND LOWER(value_source_value) LIKE '%wrong%' THEN 'error'
		WHEN value_as_number IS NULL AND LOWER(value_source_value) LIKE '%error%' THEN 'error'
		WHEN value_as_number IS NULL AND LOWER(value_source_value) LIKE '%received%' THEN 'error'
		WHEN value_as_number IS NULL AND LOWER(value_source_value) LIKE '%cancel%' THEN 'error'
		WHEN value_as_number IS NULL AND LOWER(value_source_value) LIKE '%inconclusive%' THEN 'error'
		WHEN value_as_number IS NULL AND LOWER(value_source_value) LIKE '%uncertain%' THEN 'error'
		WHEN value_as_number IS NULL AND LOWER(value_source_value) LIKE '%comment%' THEN 'error'
		WHEN value_as_number IS NULL AND LOWER(value_source_value) LIKE '%not offered%' THEN 'error'
		WHEN value_as_number IS NULL AND LOWER(value_source_value) LIKE '%no longer%' THEN 'error'
		WHEN value_as_number IS NULL AND LOWER(value_source_value) LIKE '%lost%' THEN 'error'
		WHEN value_as_number IS NULL AND LOWER(value_source_value) LIKE '%no suitable%' THEN 'error'
		WHEN value_as_number IS NULL AND LOWER(value_source_value) LIKE '%no longer available%' THEN 'error'
		WHEN value_as_number IS NULL AND LOWER(value_source_value) LIKE '%lab accident%' THEN 'error'
		WHEN value_as_number IS NULL AND LOWER(value_source_value) LIKE '%leaked%' THEN 'error'
		WHEN value_as_number IS NULL AND LOWER(value_source_value) LIKE '%note%' THEN 'error'
		WHEN value_as_number IS NULL AND LOWER(value_source_value) LIKE '%discrepancy%' THEN 'error'
		ELSE value_source_value 
	END AS hpylori_result
INTO #Hpylori_all
FROM omop.cdm_phi.measurement
WHERE measurement_concept_id IN (3007894, 3016100, 3027491, 3023871, 3018195, 36304847, 3013139, 3010921, 3011630, 3016410)
AND measurement_date BETWEEN '1973-02-01' AND '2005-07-01' -- restrict to -15 months from encounter date; change me 
AND person_id IN (SELECT DISTINCT pt_id FROM #Demographics)

DROP TABLE IF EXISTS #Hpylori_hx;
SELECT 
	pt_id,
	MIN(hpylori_date) as hpylori_dx_date,
	MAX(CASE 
		WHEN hpylori_result = 'high' THEN 1
		WHEN hpylori_result = 'not high' THEN 0 
		WHEN hpylori_result = 'error' THEN -1 
		ELSE -2 -- if there are a lot of -2s then might be worth the time to go back and clean up the extra values a bit more
	END) AS hpylori_hx
INTO #Hpylori_hx
FROM #Hpylori_all 
GROUP BY pt_id 

DROP TABLE IF EXISTS #Hpylori_active;
SELECT 
	pt_id,
	MIN(hpylori_date) as hpylori_active_date,
	MAX(CASE 
		WHEN hpylori_result = 'high' THEN 1
		WHEN hpylori_result = 'not high' THEN 0 
		WHEN hpylori_result = 'error' THEN -1 
		ELSE -2 -- if there are a lot of -2s then might be worth the time to go back and clean up the extra values a bit more
	END) AS hpylori_active
INTO #Hpylori_active
FROM #Hpylori_all 
-- active infection (IgM, stool Ag, IgA, urea breath)
WHERE hpylori_id IN (3007894, 3016100, 3018195, 36304847, 3013139, 3010921, 3011630, 3016410)
GROUP BY pt_id 

/* 
 * Generate temporary tables to get baseline and prior data by creating Common Table Expressions.
 */

-- Get all BMIs within 6 months prior to the visit date and order by the value closest to the visit date 
DROP TABLE IF EXISTS #BMI_baseline;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	b.bmi_value,
	b.bmi_num,
	b.bmi_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, e.visit_start_date, b.bmi_date))) AS rn
INTO #BMI_baseline
FROM #Encounters e
JOIN #BMI b 
	ON e.pt_id = b.pt_id 
	AND b.bmi_date BETWEEN DATEADD(month, -6, e.visit_start_date) AND e.visit_start_date

-- Get all BMIs within 9-15 months and order by value closest to 12 months prior
DROP TABLE IF EXISTS #BMI_prior;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	b.bmi_value,
	b.bmi_num,
	b.bmi_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, DATEADD(month, -12, e.visit_start_date), b.bmi_date))) AS rn 
INTO #BMI_prior
FROM #Encounters e
JOIN #BMI b
	ON e.pt_id = b.pt_id 
	AND b.bmi_date BETWEEN DATEADD(month, -15, e.visit_start_date) AND DATEADD(month, -9, e.visit_start_date)

-- Get all Hgballs within 6 months prior to the visit date and order by the value closest to the visit date 
DROP TABLE IF EXISTS #Hgball_baseline;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	b.hgball_value,
	b.hgball_num,
	b.hgball_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, e.visit_start_date, b.hgball_date))) AS rn
INTO #Hgball_baseline
FROM #Encounters e
JOIN #Hgb_all b
	ON e.pt_id = b.pt_id 
	AND b.hgball_date BETWEEN DATEADD(month, -6, e.visit_start_date) AND e.visit_start_date

-- Get all Hgballs within 9-15 months and order by value closest to 12 months prior
DROP TABLE IF EXISTS #Hgball_prior;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	b.hgball_value,
	b.hgball_num,
	b.hgball_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, DATEADD(month, -12, e.visit_start_date), b.hgball_date))) AS rn 
INTO #Hgball_prior
FROM #Encounters e
JOIN #Hgb_all b
	ON e.pt_id = b.pt_id 
	AND b.hgball_date BETWEEN DATEADD(month, -15, e.visit_start_date) AND DATEADD(month, -9, e.visit_start_date)

-- Get all Hgbs within 6 months prior to the visit date and order by the value closest to the visit date 
DROP TABLE IF EXISTS #Hgb_baseline;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	b.hgb_value,
	b.hgb_num,
	b.hgb_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, e.visit_start_date, b.hgb_date))) AS rn
INTO #Hgb_baseline
FROM #Encounters e
JOIN #Hgb b
	ON e.pt_id = b.pt_id 
	AND b.hgb_date BETWEEN DATEADD(month, -6, e.visit_start_date) AND e.visit_start_date

-- Get all Hgbs within 9-15 months and order by value closest to 12 months prior
DROP TABLE IF EXISTS #Hgb_prior;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	b.hgb_value,
	b.hgb_num,
	b.hgb_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, DATEADD(month, -12, e.visit_start_date), b.hgb_date))) AS rn 
INTO #Hgb_prior
FROM #Encounters e
JOIN #Hgb b
	ON e.pt_id = b.pt_id 
	AND b.hgb_date BETWEEN DATEADD(month, -15, e.visit_start_date) AND DATEADD(month, -9, e.visit_start_date)

-- Get all Mcvs within 6 months of the visit date and order by the value closest to the visit date 
DROP TABLE IF EXISTS #Mcv_baseline;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	b.mcv_value,
	b.mcv_num,
	b.mcv_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, e.visit_start_date, b.mcv_date))) AS rn
INTO #Mcv_baseline
FROM #Encounters e
JOIN #Mcv b 
	ON e.pt_id = b.pt_id 
	AND b.mcv_date BETWEEN DATEADD(month, -6, e.visit_start_date) AND e.visit_start_date

-- Get all Mcvs within 9-15 months and order by value closest to 12 months prior
DROP TABLE IF EXISTS #Mcv_prior;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	b.mcv_value,
	b.mcv_num,
	b.mcv_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, DATEADD(month, -12, e.visit_start_date), b.mcv_date))) AS rn 
INTO #Mcv_prior
FROM #Encounters e
JOIN #Mcv b 
	ON e.pt_id = b.pt_id 
	AND b.mcv_date BETWEEN DATEADD(month, -15, e.visit_start_date) AND DATEADD(month, -9, e.visit_start_date)

-- Get all potassiums within 6 months of the visit date and order by the value closest to the visit date 
DROP TABLE IF EXISTS #Potassium_baseline;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	b.potassium_value,
	b.potassium_num,
	b.potassium_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, e.visit_start_date, b.potassium_date))) AS rn
INTO #Potassium_baseline
FROM #Encounters e
JOIN #Potassium b 
	ON e.pt_id = b.pt_id 
	AND b.potassium_date BETWEEN DATEADD(month, -6, e.visit_start_date) AND e.visit_start_date

-- Get all potassiums within 9-15 months and order by value closest to 12 months prior
DROP TABLE IF EXISTS #Potassium_prior;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	b.potassium_value,
	b.potassium_num,
	b.potassium_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, DATEADD(month, -12, e.visit_start_date), b.potassium_date))) AS rn 
INTO #Potassium_prior
FROM #Encounters e
JOIN #Potassium b 
	ON e.pt_id = b.pt_id 
	AND b.potassium_date BETWEEN DATEADD(month, -15, e.visit_start_date) AND DATEADD(month, -9, e.visit_start_date)


-- Get all magnesiums within 6 months of the visit date and order by the value closest to the visit date 
DROP TABLE IF EXISTS #Magnesium_baseline;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	b.magnesium_value,
	b.magnesium_num,
	b.magnesium_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, e.visit_start_date, b.magnesium_date))) AS rn
INTO #Magnesium_baseline
FROM #Encounters e
JOIN #Magnesium b 
	ON e.pt_id = b.pt_id 
	AND b.magnesium_date BETWEEN DATEADD(month, -6, e.visit_start_date) AND e.visit_start_date

-- Get all magnesiums within 9-15 months and order by value closest to 12 months prior
DROP TABLE IF EXISTS #Magnesium_prior;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	b.magnesium_value,
	b.magnesium_num,
	b.magnesium_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, DATEADD(month, -12, e.visit_start_date), b.magnesium_date))) AS rn 
INTO #Magnesium_prior
FROM #Encounters e
JOIN #Magnesium b 
	ON e.pt_id = b.pt_id 
	AND b.magnesium_date BETWEEN DATEADD(month, -15, e.visit_start_date) AND DATEADD(month, -9, e.visit_start_date)


-- Get all calciums within 6 months of the visit date and order by the value closest to the visit date 
DROP TABLE IF EXISTS #Calcium_baseline;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	b.calcium_value,
	b.calcium_num,
	b.calcium_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, e.visit_start_date, b.calcium_date))) AS rn
INTO #Calcium_baseline
FROM #Encounters e
JOIN #Calcium b 
	ON e.pt_id = b.pt_id 
	AND b.calcium_date BETWEEN DATEADD(month, -6, e.visit_start_date) AND e.visit_start_date

-- Get all calciums within 9-15 months and order by value closest to 12 months prior
DROP TABLE IF EXISTS #Calcium_prior;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	b.calcium_value,
	b.calcium_num,
	b.calcium_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, DATEADD(month, -12, e.visit_start_date), b.calcium_date))) AS rn 
INTO #Calcium_prior
FROM #Encounters e
JOIN #Calcium b 
	ON e.pt_id = b.pt_id 
	AND b.calcium_date BETWEEN DATEADD(month, -15, e.visit_start_date) AND DATEADD(month, -9, e.visit_start_date)

-- Get all phosphates within 6 months of the visit date and order by the value closest to the visit date 
DROP TABLE IF EXISTS #Phosphate_baseline;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	b.phosphate_value,
	b.phosphate_num,
	b.phosphate_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, e.visit_start_date, b.phosphate_date))) AS rn
INTO #Phosphate_baseline
FROM #Encounters e
JOIN #Phosphate b 
	ON e.pt_id = b.pt_id 
	AND b.phosphate_date BETWEEN DATEADD(month, -6, e.visit_start_date) AND e.visit_start_date

-- Get all phosphates within 9-15 months and order by value closest to 12 months prior
DROP TABLE IF EXISTS #Phosphate_prior;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	b.phosphate_value,
	b.phosphate_num,
	b.phosphate_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, DATEADD(month, -12, e.visit_start_date), b.phosphate_date))) AS rn 
INTO #Phosphate_prior
FROM #Encounters e
JOIN #Phosphate b 
	ON e.pt_id = b.pt_id 
	AND b.phosphate_date BETWEEN DATEADD(month, -15, e.visit_start_date) AND DATEADD(month, -9, e.visit_start_date)


-- Get all triglyceridess within 6 months of the visit date and order by the value closest to the visit date 
DROP TABLE IF EXISTS #Triglycerides_baseline;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	b.triglycerides_value,
	b.triglycerides_num,
	b.triglycerides_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, e.visit_start_date, b.triglycerides_date))) AS rn
INTO #Triglycerides_baseline
FROM #Encounters e
JOIN #Triglycerides b 
	ON e.pt_id = b.pt_id 
	AND b.triglycerides_date BETWEEN DATEADD(month, -6, e.visit_start_date) AND e.visit_start_date

-- Get all triglyceridess within 9-15 months and order by value closest to 12 months prior
DROP TABLE IF EXISTS #Triglycerides_prior;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	b.triglycerides_value,
	b.triglycerides_num,
	b.triglycerides_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, DATEADD(month, -12, e.visit_start_date), b.triglycerides_date))) AS rn 
INTO #Triglycerides_prior
FROM #Encounters e
JOIN #Triglycerides b 
	ON e.pt_id = b.pt_id 
	AND b.triglycerides_date BETWEEN DATEADD(month, -15, e.visit_start_date) AND DATEADD(month, -9, e.visit_start_date)

-- Get all LDLs within 6 months of the visit date and order by the value closest to the visit date 
DROP TABLE IF EXISTS #LDL_baseline;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	b.LDL_value,
	b.LDL_num,
	b.LDL_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, e.visit_start_date, b.LDL_date))) AS rn
INTO #LDL_baseline
FROM #Encounters e
JOIN #LDL b 
	ON e.pt_id = b.pt_id 
	AND b.LDL_date BETWEEN DATEADD(month, -6, e.visit_start_date) AND e.visit_start_date

-- Get all LDLs within 9-15 months and order by value closest to 12 months prior
DROP TABLE IF EXISTS #LDL_prior;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	b.LDL_value,
	b.LDL_num,
	b.LDL_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, DATEADD(month, -12, e.visit_start_date), b.LDL_date))) AS rn 
INTO #LDL_prior
FROM #Encounters e
JOIN #LDL b 
	ON e.pt_id = b.pt_id 
	AND b.LDL_date BETWEEN DATEADD(month, -15, e.visit_start_date) AND DATEADD(month, -9, e.visit_start_date)

-- Get all hgba1cs within 6 months of the visit date and order by the value closest to the visit date 
DROP TABLE IF EXISTS #Hgba1c_baseline;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	b.hgba1c_value,
	b.hgba1c_num,
	b.hgba1c_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, e.visit_start_date, b.hgba1c_date))) AS rn
INTO #Hgba1c_baseline
FROM #Encounters e
JOIN #Hgba1c b 
	ON e.pt_id = b.pt_id 
	AND b.hgba1c_date BETWEEN DATEADD(month, -6, e.visit_start_date) AND e.visit_start_date

-- Get all hgba1cs within 9-15 months and order by value closest to 12 months prior
DROP TABLE IF EXISTS #Hgba1c_prior;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	b.hgba1c_value,
	b.hgba1c_num,
	b.hgba1c_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, DATEADD(month, -12, e.visit_start_date), b.hgba1c_date))) AS rn 
INTO #Hgba1c_prior
FROM #Encounters e
JOIN #Hgba1c b 
	ON e.pt_id = b.pt_id 
	AND b.hgba1c_date BETWEEN DATEADD(month, -15, e.visit_start_date) AND DATEADD(month, -9, e.visit_start_date)

/*
 * Comorbidities
 */ 

-- Multiple ICDs correspond to one SNOMED code. This table creates a dictionary for ICD/SNOMED mapping. 
DROP TABLE IF EXISTS #ICD_dict;
SELECT 
     c1.concept_code AS icd10, 
     c2.concept_code snomed
INTO #ICD_dict
FROM omop.cdm_phi.concept_relationship AS cr 
INNER JOIN omop.cdm_phi.concept AS c1 ON cr.concept_id_1 = c1.concept_id
INNER JOIN omop.cdm_phi.concept AS c2 ON cr.concept_id_2 = c2.concept_id
WHERE cr.relationship_id = 'Maps to' AND c1.vocabulary_id = 'ICD10' AND c2.vocabulary_id = 'SNOMED'

-- Gastric cancer
DROP TABLE IF EXISTS #GastricCa;
SELECT 
     person_id AS pt_id,
     MIN(condition_start_date) AS gastricca_start_date,
     1 AS gastricca
INTO #GastricCa
FROM omop.cdm_phi.condition_occurrence AS co
INNER JOIN #ICD_dict id ON co.condition_concept_code = id.snomed
WHERE id.snomed = '363349007' OR id.icd10 LIKE 'C16.%'
AND person_id IN (SELECT DISTINCT pt_id FROM #Demographics)
AND condition_start_date <= '2005-06-01' -- change me to the last encounter date
GROUP BY person_id

-- Esophageal cancer
DROP TABLE IF EXISTS #EsophagealCa;
SELECT 
     person_id AS pt_id,
     MIN(condition_start_date) AS esophagealca_start_date,
     1 AS esophagealca
INTO #EsophagealCa
FROM omop.cdm_phi.condition_occurrence AS co
INNER JOIN #ICD_dict id ON co.condition_concept_code = id.snomed
WHERE id.snomed = '126817006' OR id.icd10 LIKE 'C15.%'
AND person_id IN (SELECT DISTINCT pt_id FROM #Demographics)
AND condition_start_date <= '2005-06-01' -- change me to the last encounter date
GROUP BY person_id

-- Head and neck cancer (based on ESGE screening for esophageal SCC)
DROP TABLE IF EXISTS #HNCancer;
SELECT 
     person_id AS pt_id,
     MIN(condition_start_date) AS hnca_start_date,
     1 AS hnca
INTO #HNCancer
FROM omop.cdm_phi.condition_occurrence AS co
INNER JOIN #ICD_dict id ON co.condition_concept_code = id.snomed
WHERE id.snomed = '255055008' OR id.icd10 LIKE 'C76.0'
AND person_id IN (SELECT DISTINCT pt_id FROM #Demographics)
AND condition_start_date <= '2005-06-01' -- change me to the last encounter date
GROUP BY person_id

-- Achalasia (based on ESGE screening for esophageal SCC)
DROP TABLE IF EXISTS #Achalasia;
SELECT 
     person_id AS pt_id,
     MIN(condition_start_date) AS achalasia_start_date,
     1 AS achalasia
INTO #Achalasia
FROM omop.cdm_phi.condition_occurrence AS co
INNER JOIN #ICD_dict id ON co.condition_concept_code = id.snomed
WHERE id.snomed = '48531003' OR id.icd10 LIKE 'K22.0'
AND person_id IN (SELECT DISTINCT pt_id FROM #Demographics)
AND condition_start_date <= '2005-06-01' -- change me to the last encounter date
GROUP BY person_id

-- Peptic ulcer
DROP TABLE IF EXISTS #PUD;
SELECT 
     person_id AS pt_id,
     MIN(condition_start_date) AS pud_start_date,
     1 AS pud
INTO #PUD
FROM omop.cdm_phi.condition_occurrence AS co
INNER JOIN #ICD_dict id ON co.condition_concept_code = id.snomed
WHERE id.snomed = '13200003' OR id.icd10 LIKE 'K25.%' OR id.icd10 LIKE 'K27.%'
AND person_id IN (SELECT DISTINCT pt_id FROM #Demographics)
AND condition_start_date <= '2005-06-01' -- change me to the last encounter date
GROUP BY person_id

-- GERD
DROP TABLE IF EXISTS #GERD
SELECT 
     person_id AS pt_id,
     MIN(condition_start_date) AS gerd_start_date,
     1 AS gerd
INTO #GERD
FROM omop.cdm_phi.condition_occurrence AS co
INNER JOIN #ICD_dict id ON co.condition_concept_code = id.snomed
WHERE id.snomed = '235595009' OR id.icd10 LIKE 'K21.%'
AND person_id IN (SELECT DISTINCT pt_id FROM #Demographics)
AND condition_start_date <= '2005-06-01' -- change me to the last encounter date
GROUP BY person_id

-- H pylori 
DROP TABLE IF EXISTS #Hpylori_ICD;
SELECT 
     person_id AS pt_id,
     MIN(condition_start_date) AS hpylori_start_date,
     1 AS hpylori
INTO #Hpylori_ICD
FROM omop.cdm_phi.condition_occurrence AS co
INNER JOIN #ICD_dict id ON co.condition_concept_code = id.snomed
WHERE id.snomed = '13200003' OR id.icd10 LIKE 'K25.%' OR id.icd10 LIKE 'K27.%'
AND person_id IN (SELECT DISTINCT pt_id FROM #Demographics)
AND condition_start_date <= '2005-06-01' -- change me to the last encounter date
GROUP BY person_id

-- Coronary artery disease
DROP TABLE IF EXISTS #CAD;
SELECT 
     person_id AS pt_id,
     MIN(condition_start_date) AS cad_start_date,
     1 AS cad
INTO #CAD
FROM omop.cdm_phi.condition_occurrence AS co
INNER JOIN #ICD_dict id ON co.condition_concept_code = id.snomed
WHERE id.snomed = '53741008' OR id.icd10 LIKE 'I25.%'
AND person_id IN (SELECT DISTINCT pt_id FROM #Demographics)
AND condition_start_date <= '2005-06-01' -- change me to the last encounter date
GROUP BY person_id

-- Tobacco use 
DROP TABLE IF EXISTS #Tobacco_ICD;
SELECT 
     person_id AS pt_id,
     MIN(condition_start_date) AS tobacco_start_date,
     1 AS tobacco
INTO #Tobacco_ICD
FROM omop.cdm_phi.condition_occurrence AS co
INNER JOIN #ICD_dict id ON co.condition_concept_code = id.snomed
WHERE id.snomed = '56294008' OR id.icd10 = 'Z72.0' OR id.icd10 LIKE 'F17.%'
AND person_id IN (SELECT DISTINCT pt_id FROM #Demographics)
AND condition_start_date <= '2005-06-01' -- change me to the last encounter date
GROUP BY person_id

-- Alcohol use 
DROP TABLE IF EXISTS #Alcohol_ICD;
SELECT 
     person_id AS pt_id,
     MIN(condition_start_date) AS alcohol_start_date,
     1 AS alcohol
INTO #Alcohol_ICD
FROM omop.cdm_phi.condition_occurrence AS co
INNER JOIN #ICD_dict id ON co.condition_concept_code = id.snomed
WHERE id.snomed = '66590003' OR id.icd10 LIKE 'F10.%'
AND person_id IN (SELECT DISTINCT pt_id FROM #Demographics)
AND condition_start_date <= '2005-06-01' -- change me to the last encounter date
GROUP BY person_id

/*
 * Family history 
 */ 

DROP TABLE IF EXISTS #Famhx_cancer;
SELECT 
    person_id AS pt_id,
    MAX(CASE 
	    WHEN (LOWER(xtn_value_as_source_concept_name) LIKE '%cancer%' OR LOWER(xtn_value_as_source_concept_name) LIKE '%carcinoma%') THEN 1 
    	ELSE 0 
    END) AS famhx_cancer,
    MAX(CASE 
    	WHEN (LOWER(xtn_value_as_source_concept_name) LIKE '%gastric%' OR LOWER(xtn_value_as_source_concept_name) LIKE '%stomach%') 
    	AND (LOWER(xtn_value_as_source_concept_name) LIKE '%cancer%' OR LOWER(xtn_value_as_source_concept_name) LIKE '%carcinoma%') THEN 1 
    	ELSE 0
    END) AS famhx_gastricca,
    MAX(CASE 
    	WHEN (LOWER(xtn_value_as_source_concept_name) LIKE '%colo%' OR LOWER(xtn_value_as_source_concept_name) LIKE '%rectal%') 
    	AND (LOWER(xtn_value_as_source_concept_name) LIKE '%cancer%' OR LOWER(xtn_value_as_source_concept_name) LIKE '%carcinoma%') THEN 1 
    	ELSE 0
    END) AS famhx_colonca,
    MAX(CASE 
    	WHEN (LOWER(xtn_value_as_source_concept_name) LIKE '%esophageal%') 
    	AND (LOWER(xtn_value_as_source_concept_name) LIKE '%cancer%' OR LOWER(xtn_value_as_source_concept_name) LIKE '%carcinoma%') THEN 1 
    	ELSE 0
    END) AS famhx_esophagealca
INTO #Famhx_cancer
FROM omop.cdm_phi.observation 
WHERE (observation_concept_name = 'Family history with explicit context' 
    OR  observation_concept_name = 'Family history of clinical finding') 
    AND person_id IN (SELECT DISTINCT pt_id FROM #Encounters)
GROUP BY person_id

/*
 * Social history
 * Since there can be many : one observations for each patient, I applied the following logic. For language, race, and ethnicity, count the entries and select the one that is most frequent. If all equal, select by alphabetical order (since "Other", "White", "Unknown" all fall toward the end of the alphabet)
 */

DROP TABLE IF EXISTS #Social_Language;
SELECT 
    pt_id, 
    social_language, 
    COUNT(*) AS count, 
    ROW_NUMBER() OVER (PARTITION BY pt_id ORDER BY social_language, COUNT(social_language)) AS rn
INTO #Social_Language
FROM (
    SELECT 
        person_id AS pt_id,
        xtn_value_as_source_concept_name AS social_language
    FROM omop.cdm_phi.observation 
    WHERE observation_concept_name = 'Language preference'
        AND person_id IN (SELECT DISTINCT pt_id FROM #Encounters)
) a 
GROUP BY pt_id, social_language 

DROP TABLE IF EXISTS #Social_Race;
SELECT 
    pt_id, 
    social_race, 
    COUNT(*) AS count, 
    ROW_NUMBER() OVER (PARTITION BY pt_id ORDER BY social_race, COUNT(social_race)) AS rn
INTO #Social_Race
FROM (
    SELECT 
        person_id AS pt_id,
        xtn_value_as_source_concept_name AS social_race
    FROM omop.cdm_phi.observation 
    WHERE observation_concept_name IN ('Race or ethnicity', 'Race','Tabulated race [CDC]')
        AND person_id IN (SELECT DISTINCT pt_id FROM #Encounters)
) a 
GROUP BY pt_id, social_race 

DROP TABLE IF EXISTS #Social_Ethnicity;
SELECT 
    pt_id, 
    social_ethnicity, 
    COUNT(*) AS count, 
    ROW_NUMBER() OVER (PARTITION BY pt_id ORDER BY social_ethnicity, COUNT(social_ethnicity)) AS rn
INTO #Social_Ethnicity
FROM (
    SELECT 
        person_id AS pt_id,
        xtn_value_as_source_concept_name AS social_ethnicity
    FROM omop.cdm_phi.observation 
    WHERE observation_concept_name IN ('Race or ethnicity', 'Tabulated ethnicity [CDC]', 'Ethnic background', 'Ethnic group')
        AND person_id IN (SELECT DISTINCT pt_id FROM #Encounters)
) a 
GROUP BY pt_id, social_ethnicity 

DROP TABLE IF EXISTS #Social_Alcohol;
SELECT 
    person_id AS pt_id,
    MAX(CASE 
        WHEN xtn_value_as_source_concept_name = 'Yes' THEN 2
        WHEN xtn_value_as_source_concept_name = 'Not Currently' THEN 1
        WHEN xtn_value_as_source_concept_name IN ('No', 'Never') THEN 0 
        WHEN xtn_value_as_source_concept_name IN ('Not Asked', 'No matching concept') THEN -1
    END) AS social_alcohol,
    MAX(CASE 
        -- rename so there is an numerical order that cooresponds to the natural ordinal position so we can use the aggregate function MAX
        WHEN observation_concept_name = 'How often do you have 6 or more drinks on 1 occasion' AND value_as_concept_name = 'Daily or almost daily' THEN '4: Daily or almost daily' 
        WHEN observation_concept_name = 'How often do you have 6 or more drinks on 1 occasion' AND value_as_concept_name = 'Weekly' THEN '3: Weekly' 
        WHEN observation_concept_name = 'How often do you have 6 or more drinks on 1 occasion' AND value_as_concept_name = 'Monthly' THEN '2: Monthly' 
        WHEN observation_concept_name = 'How often do you have 6 or more drinks on 1 occasion' AND value_as_concept_name = 'Less than monthly' THEN '1: Less than monthly' 
        WHEN observation_concept_name = 'How often do you have 6 or more drinks on 1 occasion' AND value_as_concept_name = 'Never' THEN '0: Never' 
        WHEN observation_concept_name = 'How often do you have 6 or more drinks on 1 occasion' AND value_as_concept_name = 'Not asked' THEN '-1: Not asked' 
        WHEN observation_concept_name = 'How often do you have 6 or more drinks on 1 occasion' AND value_as_concept_name = 'Patient refused' THEN '-1: Patient refused' 
    END) AS social_alcohol_binge_freq, 
    MAX(CASE 
        -- there is a natural ordinal progression so no need to rename
        -- '2-3 times a week', '2-4 times a month', '4 or more times a week', 'Monthly or less', 'Never', 'Not asked', 'Patient refused'
        WHEN observation_concept_name = 'How often do you have a drink containing alcohol' THEN value_as_concept_name
        ELSE NULL 
    END) AS social_alcohol_drink_freq,
    MAX(CASE 
        WHEN observation_concept_name = 'How many standard drinks containing alcohol do you have on a typical day' AND value_as_concept_name = '10 or more' THEN '5: 10 or more'
        WHEN observation_concept_name = 'How many standard drinks containing alcohol do you have on a typical day' AND value_as_concept_name = '7 to 9' THEN '4: 7 to 9'
        WHEN observation_concept_name = 'How many standard drinks containing alcohol do you have on a typical day' AND value_as_concept_name = '5 or 6' THEN '3: 5 or 6'
        WHEN observation_concept_name = 'How many standard drinks containing alcohol do you have on a typical day' AND value_as_concept_name = '3 or 4' THEN '2: 3 or 4'
        WHEN observation_concept_name = 'How many standard drinks containing alcohol do you have on a typical day' AND value_as_concept_name = '1 or 2' THEN '1: 1 or 2'
        WHEN observation_concept_name = 'How many standard drinks containing alcohol do you have on a typical day' AND value_as_concept_name = 'Not asked' THEN '0: Not asked'
        WHEN observation_concept_name = 'How many standard drinks containing alcohol do you have on a typical day' AND value_as_concept_name = 'Patient refused' THEN '0: Patient refused'
        ELSE NULL
    END) AS social_alcohol_drinks_day
INTO #Social_Alcohol
FROM omop.cdm_phi.observation 
WHERE observation_concept_name IN ('Assessment of alcohol use', 'History of Alcohol use Narrative',
    'How often do you have 6 or more drinks on 1 occasion', 'How often do you have a drink containing alcohol', 'How many standard drinks containing alcohol do you have on a typical day')
    AND observation_date <= '2005-06-01' -- change me to the last encounter date
GROUP BY person_id

DROP TABLE IF EXISTS #Social_Smoking;
SELECT 
    person_id AS pt_id,
    MAX(CASE 
        WHEN xtn_value_as_source_concept_name IN ('Never', 'Passive Smoke Exposure - Never Smoker', 'Passive') THEN 0
        WHEN xtn_value_as_source_concept_name IN ('Unknown', 'Not Asked', 'No matching concept', 'Never Assessed') THEN -1
        WHEN xtn_value_as_source_concept_name IN ('Some Days', 'Light Smoker', 'Every Day', 'Cigarettes', 'Former', 'Quit', 'Yes', 'Smoker, Current Status Unknown', 'Heavy Smoker') THEN 1
    END) AS social_smoking_ever,
    MAX(CASE 
        WHEN xtn_value_as_source_concept_name IN ('Former', 'Quit') THEN 1
        ELSE NULL
    END) AS social_smoking_quit,
    MAX(CASE
        WHEN observation_concept_name = 'Cigarettes smoked current (pack per day) - Reported' THEN value_as_number
        ELSE NULL
    END) AS social_smoking_ppd,
    MIN(CASE 
        WHEN observation_concept_name = 'Smoking started' THEN value_as_datetime
        ELSE NULL
    END) AS social_smoking_start_date,
    MAX(CASE 
        WHEN observation_concept_name = 'Date quit tobacco smoking' THEN value_as_datetime
        ELSE NULL
    END) AS social_smoking_quit_date
INTO #Social_Smoking
FROM omop.cdm_phi.observation 
WHERE observation_concept_name IN ('Cigarette consumption', 'Cigarettes smoked current (pack per day) - Reported', 
    'Tobacco usage screening', 'Smoking assessment',
	'Smoking started', 'Date quit tobacco smoking')
    AND observation_date <= '2005-06-01' -- change me to the last encounter date
GROUP BY person_id

DROP TABLE IF EXISTS #Social_Smoking_Narrative;
SELECT 
    person_id AS pt_id,
    observation_date,
    value_as_string AS social_smoking_narrative,
    ROW_NUMBER() OVER (PARTITION BY person_id ORDER BY observation_date DESC) AS rn
INTO #Social_Smoking_Narrative
FROM omop.cdm_phi.observation
WHERE observation_concept_name = 'History of Tobacco use Narrative'
AND observation_date <= '2005-06-01' -- change me to the last encounter date

/*
 * Medications 
 */

DROP TABLE IF EXISTS #Meds;
SELECT 
    person_id AS pt_id,
    MIN(
        CASE 
            WHEN xtn_generic_ingredient_source_concept_name IN ('butalbital/aspirin/caffeine', 'ASA/acetaminophen/caffeine/pot', 'ASA/salicylam/acetaminoph/caff', 'aspirin', 'aspirin/acetaminophen/caffeine', 'aspirin/caffeine', 'aspirin/calcium carb/magnesium', 'aspirin/calcium carbonate', 'aspirin/calcium/mag/aluminum', 'aspirin/sod bicarb/citric acid', 'aspirin/acetaminophen/cal carb', 'aspirin/codeine phosphate', 'hydrocodone bitartrate/aspirin', 'oxycodone HCl,terephth/aspirin', 'oxycodone HCl/aspirin', 'codeine/butalbital/ASA/caffein', 'carisoprodol/aspirin/codeine')
                THEN drug_exposure_start_date
            ELSE NULL 
        END) AS ASA_start_date,
    MIN(
        CASE 
            WHEN xtn_generic_ingredient_source_concept_name IN ('ibuprofen/diphenhydramine cit', 'ibuprofen/diphenhydramine HCl', 'naproxen sod/diphenhydramine', 'diflunisal', 'ibuprofen/acetaminophen', 'ibuprofen/famotidine', 'naproxen/esomeprazole mag', 'diclofenac sodium/misoprostol', 'diclofenac potassium', 'diclofenac sodium', 'diclofenac submicronized', 'etodolac', 'fenoprofen calcium', 'flurbiprofen', 'ibuprofen', 'ibuprofen/glycerin', 'indomethacin', 'indomethacin, submicronized', 'ketoprofen', 'ketorolac tromethamine', 'meclofenamate sodium', 'mefenamic acid', 'meloxicam', 'meloxicam, submicronized', 'nabumetone', 'naproxen', 'naproxen sodium', 'oxaprozin', 'piroxicam', 'sulindac', 'tolmetin sodium', 'celecoxib', 'Ibuprofen/Caff/B1/B2/B6/B12', 'hydrocodone/ibuprofen', 'ibuprofen/oxycodone HCl', 'tramadol HCl/celecoxib')             
            THEN drug_exposure_start_date
            ELSE NULL 
        END) AS NSAID_start_date,
    MIN(
        CASE 
            WHEN xtn_generic_ingredient_source_concept_name IN ('naproxen/esomeprazole mag', 'dexlansoprazole', 'esomeprazole mag/glycerin', 'Esomeprazole Magnesium', 'esomeprazole sodium', 'esomeprazole strontium', 'lansoprazole', 'omeprazole', 'omeprazole magnesium', 'omeprazole/sodium bicarbonate', 'pantoprazole sodium', 'rabeprazole sodium')
            THEN drug_exposure_start_date
            ELSE NULL 
        END) AS PPI_start_date
INTO #Meds
FROM omop.cdm_phi.drug_exposure 
WHERE xtn_pharmaceutical_class_source_concept_name IN ('NSAID,COX INHIBITOR-TYPE AND PROTON-PUMP INHIBITOR', 'NSAID ANALGESIC AND NON-SALICYLATE ANALGESIC COMB', 'NSAIDS (SYSTEMIC)-TOPICAL LOCAL ANESTHETIC COMBO', 'ANALGESIC, SALICYLATE, BARBITURATE, XANTHINE COMB.', 'SKELETAL MUSCLE RELAXANT,SALICYLAT,OPIOID ANALGESC', 'TOPICAL ANTI-INFLAMMATORY, NSAIDS', 'OPIOID ANALGESIC AND NSAID COMBINATION', 'OPIOID AND SALICYLATE ANALGESICS,BARBIT,XANTHINE', 'ANALGESICS, SALICYLATE AND NON-SALICYLATE COMB.', 'NSAIDS,CYCLOOXYGENASE-2(COX-2) SELECTIVE INHIBITOR', 'PROTON-PUMP INHIBITORS', 'NSAIDS(COX NON-SPEC.INHIB)AND PROSTAGLANDIN ANALOG', 'NSAID AND HISTAMINE H2 RECEPTOR ANTAGONIST COMB.', 'NSAIDS, CYCLOOXYGENASE INHIBITOR TYPE ANALGESICS', 'NSAIDS/DIETARY SUPPLEMENT COMBINATIONS', 'ANALGESIC/ANTIPYRETICS,NON-SALICYLATE', 'ANALGESIC,NSAID-1ST GEN.ANTIHISTAMINE,SEDATIVE CMB', 'ANALGESIC/ANTIPYRETICS, SALICYLATES', 'OPIOID ANALGESIC AND SALICYLATE ANALGESIC COMB')
    AND xtn_drug_default_route_source_concept_name IN ('oral', 'intravenous')
    AND person_id IN (SELECT DISTINCT pt_id FROM #Demographics)
GROUP BY person_id 

/*
 * Final table creation 
 */

SELECT 
	d.pt_id,
	d.mrn,
	e.visit_id,

	-- Demographics
	d.sex,
	DATEDIFF(year, d.dob, e.visit_start_date) - 
		(CASE WHEN MONTH(e.visit_start_date) < MONTH(d.dob) OR (MONTH(e.visit_start_date) = MONTH(d.dob) AND DAY(e.visit_start_date) < DAY(d.dob)) THEN 1
		ELSE 0 END)
		AS age, 
	d.dob,
	d.race,
	d.ethnicity,
	d.preferred_language,

	-- Social history
	sl.social_language, 
	sr.social_race, 
	se.social_ethnicity,
	sa.social_alcohol,
	sa.social_alcohol_binge_freq, 
	sa.social_alcohol_drink_freq,
	sa.social_alcohol_drinks_day,
	ss.social_smoking_ever,
	ss.social_smoking_quit,
	ss.social_smoking_ppd,
	ss.social_smoking_start_date,
	ss.social_smoking_quit_date,
	ssn.social_smoking_narrative,
	ssn.social_smoking_narrative_date,

	-- Encounter information
	e.xtn_epic_encounter_number,
	e.etl_epic_encounter_key,
	e.encounter_type,
	e.care_site,
	e.visit_start_date,
	e.visit_end_date,
	e.visit_start_date_minus_6mo,
	e.visit_start_date_minus_9mo,
	e.visit_start_date_minus_12mo,
	e.visit_start_date_minus_18mo,

	-- Measurements, baseline and prior 
	b.bmi_num AS BMI_baseline,
	b.bmi_value AS BMI_baseline_val,
	b.bmi_date AS BMI_baseline_date,
	p.bmi_num AS BMI_prior,
	p.bmi_value AS BMI_prior_val,
	p.bmi_date AS BMI_prior_date,

	hab.hgball_num AS hgball_baseline,
	hab.hgball_value AS hgball_baseline_val,
	hab.hgball_date AS hgball_baseline_date,
	hap.hgball_num AS hgball_prior,
	hap.hgball_value AS hgball_prior_val,
	hap.hgball_date AS hgball_prior_date,

	hb.hgb_num AS hgb_baseline,
	hb.hgb_value AS hgb_baseline_val,
	hb.hgb_date AS hgb_baseline_date,
	hp.hgb_num AS hgb_prior,
	hp.hgb_value AS hgb_prior_val,
	hp.hgb_date AS hgb_prior_date,

	mb.mcv_num AS mcv_baseline,
	mb.mcv_value AS mcv_baseline_val,
	mb.mcv_date AS mcv_baseline_date,
	mp.mcv_num AS mcv_prior,
	mp.mcv_value AS mcv_prior_val,
	mp.mcv_date AS mcv_prior_date,

	pb.potassium_num AS potassium_baseline,
	pb.potassium_value AS potassium_baseline_val,
	pb.potassium_date AS potassium_baseline_date,
	pp.potassium_num AS potassium_prior,
	pp.potassium_value AS potassium_prior_val,
	pp.potassium_date AS potassium_prior_date,

	mgb.magnesium_num AS magnesium_baseline,
	mgb.magnesium_value AS magnesium_baseline_val,
	mgb.magnesium_date AS magnesium_baseline_date,
	mgp.magnesium_num AS magnesium_prior,
	mgp.magnesium_value AS magnesium_prior_val,
	mgp.magnesium_date AS magnesium_prior_date,

	cb.calcium_num AS calcium_baseline,
	cb.calcium_value AS calcium_baseline_val,
	cb.calcium_date AS calcium_baseline_date,
	cp.calcium_num AS calcium_prior,
	cp.calcium_value AS calcium_prior_val,
	cp.calcium_date AS calcium_prior_date,

	phb.phosphate_num AS phosphate_baseline,
	phb.phosphate_value AS phosphate_baseline_val,
	phb.phosphate_date AS phosphate_baseline_date,
	php.phosphate_num AS phosphate_prior,
	php.phosphate_value AS phosphate_prior_val,
	php.phosphate_date AS phosphate_prior_date,

	tb.triglycerides_num AS triglycerides_baseline,
	tb.triglycerides_value AS triglycerides_baseline_val,
	tb.triglycerides_date AS triglycerides_baseline_date,
	tp.triglycerides_num AS triglycerides_prior,
	tp.triglycerides_value AS triglycerides_prior_val,
	tp.triglycerides_date AS triglycerides_prior_date,

	lb.LDL_num AS LDL_baseline,
	lb.LDL_value AS LDL_baseline_val,
	lb.LDL_date AS LDL_baseline_date,
	lp.LDL_num AS LDL_prior,
	lp.LDL_value AS LDL_prior_val,
	lp.LDL_date AS LDL_prior_date,

	a1cb.hgba1c_num AS hgba1c_baseline,
	a1cb.hgba1c_value AS hgba1c_baseline_val,
	a1cb.hgba1c_date AS hgba1c_baseline_date,
	a1cp.hgba1c_num AS hgba1c_prior,
	a1cp.hgba1c_value AS hgba1c_prior_val,
	a1cp.hgba1c_date AS hgba1c_prior_date,

	hhx.hpylori_dx_date,
	hhx.hpylori_hx,
	hactive.hpylori_active_date,
	hactive.hpylori_active,

	-- Comorbidities
	gca.gastricca_start_date,
	gca.gastricca,

	eca.esophagealca_start_date,
	eca.esophagealca,

	hnca.hnca_start_date,
	hnca.hnca,

	ach.achalasia_start_date,
	ach.achalasia,

	pud.pud_start_date,
	pud.pud,

	gerd.gerd_start_date,
	gerd.gerd,

	hpylori.hpylori_start_date,
	hpylori.hpylori,

	cad.cad_start_date,
	cad.cad,
	
	tobacco.tobacco_start_date,
	tobacco.tobacco,

	alcohol.alcohol_start_date,
	alcohol.alcohol,

	-- Family history
	fhx.famhx_cancer,
	fhx.famhx_esophagealca,
	fhx.famhx_gastricca,
	fhx.famhx_colonca,

	-- Meds 
	meds.ASA_start_date,
	meds.NSAID_start_date,
	meds.PPI_start_date

FROM #Encounters e
JOIN #Demographics d ON e.pt_id = d.pt_id
LEFT JOIN #BMI_baseline b ON e.visit_id = b.visit_id AND b.rn = 1
LEFT JOIN #BMI_prior p ON e.visit_id = p.visit_id AND p.rn = 1 

LEFT JOIN #Hgball_baseline hab ON e.visit_id = hab.visit_id AND hab.rn=1
LEFT JOIN #Hgball_prior hap ON e.visit_id = hap.visit_id AND hap.rn=1 
LEFT JOIN #Hgb_baseline hb ON e.visit_id = hb.visit_id AND hb.rn=1
LEFT JOIN #Hgb_prior hp ON e.visit_id = hp.visit_id AND hp.rn=1

LEFT JOIN #Mcv_baseline mb ON e.visit_id = mb.visit_id AND mb.rn=1
LEFT JOIN #Mcv_prior mp ON e.visit_id = mp.visit_id AND mp.rn=1 

LEFT JOIN #Potassium_baseline pb ON e.visit_id = pb.visit_id AND pb.rn=1
LEFT JOIN #Potassium_prior pp ON e.visit_id = pp.visit_id AND pp.rn=1 

LEFT JOIN #Magnesium_baseline mgb ON e.visit_id = mgb.visit_id AND mgb.rn=1
LEFT JOIN #Magnesium_prior mgp ON e.visit_id = mgp.visit_id AND mgp.rn=1 

LEFT JOIN #Calcium_baseline cb ON e.visit_id = cb.visit_id AND cb.rn=1
LEFT JOIN #Calcium_prior cp ON e.visit_id = cp.visit_id AND cp.rn=1 

LEFT JOIN #Phosphate_baseline phb ON e.visit_id = phb.visit_id AND phb.rn=1
LEFT JOIN #Phosphate_prior php ON e.visit_id = php.visit_id AND php.rn=1 

LEFT JOIN #Triglycerides_baseline tb ON e.visit_id = tb.visit_id AND tb.rn=1
LEFT JOIN #Triglycerides_prior tp ON e.visit_id = tp.visit_id AND tp.rn=1 

LEFT JOIN #LDL_baseline lb ON e.visit_id = lb.visit_id AND lb.rn=1
LEFT JOIN #LDL_prior lp ON e.visit_id = lp.visit_id AND lp.rn=1 

LEFT JOIN #Hgba1c_baseline a1cb ON e.visit_id = a1cb.visit_id AND a1cb.rn=1
LEFT JOIN #Hgba1c_prior a1cp ON e.visit_id = a1cp.visit_id AND a1cp.rn=1 

LEFT JOIN #Hpylori_hx hhx ON e.pt_id = hhx.pt_id 
LEFT JOIN #Hpylori_active hactive ON e.pt_id = hactive.pt_id

LEFT JOIN #GastricCa gca ON e.pt_id = gca.pt_id 
LEFT JOIN #EsophagealCa eca ON e.pt_id = eca.pt_id 
LEFT JOIN #HNCancer hnca ON e.pt_id = hnca.pt_id
LEFT JOIN #Achalasia ach ON e.pt_id = ach.pt_id 
LEFT JOIN #PUD pud ON e.pt_id = pud.pt_id 
LEFT JOIN #GERD gerd ON e.pt_id = gerd.pt_id 
LEFT JOIN #Hpylori_ICD hpylori ON e.pt_id = hpylori.pt_id 
LEFT JOIN #CAD cad ON e.pt_id = cad.pt_id 
LEFT JOIN #Tobacco_ICD tobacco ON e.pt_id = tobacco.pt_id 
LEFT JOIN #Alcohol_ICD alcohol ON e.pt_id = alcohol.pt_id 

LEFT JOIN #Famhx_cancer fhx ON e.pt_id = fhx.pt_id 

LEFT JOIN #Social_Language sl ON e.pt_id = sl.pt_id 
LEFT JOIN #Social_Race sr ON e.pt_id = sr.pt_id 
LEFT JOIN #Social_Ethnicity se ON e.pt_id = se.pt_id 
LEFT JOIN #Social_Alcohol sa ON e.pt_id = sa.pt_id 
LEFT JOIN #Social_Smoking ss ON e.pt_id = ss.pt_id 
LEFT JOIN #Social_Smoking_Narrative ssn ON e.pt_id = ssn.pt_id 

LEFT JOIN #Meds meds ON e.pt_id = meds.pt_id

WHERE sl.rn = 1 
	AND sr.rn = 1 
	AND se.rn = 1 
	AND ssn.rn = 1