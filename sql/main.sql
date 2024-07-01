DROP TABLE IF EXISTS #Demographics;
SELECT TOP 1000
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

DROP TABLE IF EXISTS #BMI;
SELECT TOP 1000
	person_id as pt_id,
	measurement_concept_id as bmi_id,
	measurement_source_value as bmi_textid,
	measurement_date as bmi_date,
	value_as_number as bmi_num,
	value_source_value as bmi_value,
	unit_concept_code as bmi_unit
INTO #BMI
FROM omop.cdm_phi.measurement
WHERE measurement_concept_id IN (3038553)

DROP TABLE IF EXISTS #Hgb_all;
SELECT TOP 1000
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

DROP TABLE IF EXISTS #Hgb_clean;
SELECT TOP 1000
	person_id as pt_id,
	measurement_concept_id as hgb_id,
	measurement_source_value as hgb_textid,
	measurement_date as hgb_date,
	value_as_number as hgb_num,
	value_source_value as hgb_value,
	unit_concept_code as hgb_unit
INTO #Hgb_clean
FROM omop.cdm_phi.measurement
WHERE measurement_concept_id IN (3000963, 3006239)

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
