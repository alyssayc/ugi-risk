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
WHERE year_of_birth BETWEEN '1960' and '1961' -- delete me 

/*
 * Measurement tables 
 * To troubleshoot, limit to >2021 
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
AND measurement_date BETWEEN '2021-01-01' AND '2023-03-30' -- delete me 

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
AND measurement_date BETWEEN '2021-01-01' AND '2023-03-30' -- delete me 

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
AND measurement_date BETWEEN '2021-01-01' AND '2023-03-30' -- delete me 

DROP TABLE IF EXISTS #Hpylori;
SELECT 
	person_id as pt_id,
	measurement_concept_id as hpylori_id,
	measurement_source_value as hpylori_textid,
	measurement_date as hpylori_date,
	value_as_number as hpylori_num,
	value_source_value as hpylori_value,
	unit_concept_code as hpylori_unit,
	range_high,
	range_low,
	CASE 
		WHEN value_as_number IS NOT NULL and value_as_number > range_high THEN 'high'
		WHEN value_as_number IS NOT NULL and value_as_number <= range_high THEN 'not high'
		WHEN value_as_number IS NOT NULL and range_high IS NULL THEN 'no range' -- 'H.PYLORI IGG INDEX', 'H. PYLORI IGA', 'H. PYLORI, IGM AB'
		WHEN value_as_number IS NULL AND LOWER(value_source_value) LIKE '%duplicate%' THEN 'error'
		WHEN value_as_number IS NULL AND LOWER(value_source_value) LIKE '%equivocal%' THEN 'not high'
		WHEN value_as_number IS NULL AND LOWER(value_source_value) LIKE '%not sufficient%' THEN 'error'
		WHEN value_as_number IS NULL AND LOWER(value_source_value) LIKE '%not performed%' THEN 'error'
		WHEN value_as_number IS NULL AND LOWER(value_source_value) LIKE '%see%' THEN 'error' -- see below or see note
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
INTO #Hpylori
FROM omop.cdm_phi.measurement
WHERE measurement_concept_id IN (3007894, 3016100, 3027491, 3023871, 3018195, 36304847, 3013139, 3010921, 3011630, 3016410)
AND measurement_date BETWEEN '2021-01-01' AND '2023-03-30' -- delete me 


/* 
 * Generate temporary tables to get baseline and prior data 
 */

DROP TABLE IF EXISTS #Encounters;
SELECT
	visit_occurrence_id as visit_id,
	person_id as pt_id,
	xtn_epic_encounter_number,
	etl_epic_encounter_key,
	xtn_visit_type_source_concept_name as encounter_type,
	visit_start_date,
	visit_end_date,
	DATEADD(month, -6, visit_start_date) AS visit_start_date_minus_6mo,
	DATEADD(month, -9, visit_start_date) AS visit_start_date_minus_9mo,
	DATEADD(month, -12, visit_start_date) AS visit_start_date_minus_12mo,
	DATEADD(month, -18, visit_start_date) AS visit_start_date_minus_18mo
INTO #Encounters 
FROM omop.cdm_phi.visit_occurrence e
WHERE xtn_visit_type_source_concept_name IN ('Telehealth Visit', 'Outpatient Visit', 'Hospital Outpatient Visit', 'Inpatient Hospitalization', 'Inpatient Hospitalization from ED Visit', 'ED Visit')
AND person_id IN (SELECT DISTINCT pt_id FROM #Demographics)
-- AND visit_start_date BETWEEN '1974-06-01' AND '2023-03-30' 
-- filter by age >= 30 
-- AND visit_start_date >= DATEADD(year, 30, (SELECT DATEFROMPARTS(year_of_birth, month_of_birth, day_of_birth) as dob FROM omop.cdm_phi.person p WHERE p.person_id = e.person_id))

-- Create a Common Table Expressions to efficiently get baseline and priors 

-- Get all BMIs within 6 months of the visit date and order by the value closest to the visit date 
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


-- Get all Hgballs within 6 months of the visit date and order by the value closest to the visit date 
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

-- Get all Hgbs within 6 months of the visit date and order by the value closest to the visit date 
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


/*
 * Final table creation 
 */

SELECT 
	d.pt_id,
	e.visit_id,
	d.sex,
	DATEDIFF(year, d.dob, e.visit_start_date) - 
		(CASE WHEN MONTH(e.visit_start_date) < MONTH(d.dob) OR (MONTH(e.visit_start_date) = MONTH(d.dob) AND DAY(e.visit_start_date) < DAY(d.dob)) THEN 1
		ELSE 0 END)
		AS age, 
	d.dob,
	d.race,
	d.ethnicity,
	d.preferred_language,
	d.mrn,
	e.xtn_epic_encounter_number,
	e.etl_epic_encounter_key,
	e.encounter_type,
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
	hp.hgb_date AS hgb_prior_date

FROM #Encounters e
JOIN #Demographics d ON e.pt_id = d.pt_id
LEFT JOIN #BMI_baseline b ON e.visit_id = b.visit_id AND b.rn=1
LEFT JOIN #BMI_prior p ON e.visit_id = p.visit_id AND p.rn=1 
LEFT JOIN #Hgball_baseline hab ON e.visit_id = hab.visit_id AND hab.rn=1
LEFT JOIN #Hgball_prior hap ON e.visit_id = hap.visit_id AND hap.rn=1 
LEFT JOIN #Hgb_baseline hb ON e.visit_id = hb.visit_id AND hb.rn=1
LEFT JOIN #Hgb_prior hp ON e.visit_id = hp.visit_id AND hp.rn=1