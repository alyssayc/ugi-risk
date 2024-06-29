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
FROM omop.cdm_phi.measurement
WHERE measurement_concept_id IN (3000963, 3006239)