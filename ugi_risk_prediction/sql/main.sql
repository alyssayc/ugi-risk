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
AND visit_start_date BETWEEN '{start_date}' AND '{end_date}' -- change me 

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
	p.xtn_patient_epic_mrn as mrn,
	p.death_datetime as date_of_death
INTO #Demographics
FROM omop.cdm_phi.person p 
INNER JOIN omop.cdm_phi.concept gender_c ON gender_c.concept_id = p.gender_concept_id 
INNER JOIN omop.cdm_phi.concept race_c ON race_c.concept_id = p.race_concept_id
INNER JOIN omop.cdm_phi.concept ethnicity_c ON ethnicity_c.concept_id = p.ethnicity_concept_id 
WHERE person_id IN (SELECT pt_id FROM #Encounters)

/*
 * Measurement tables 
 */

DROP TABLE IF EXISTS #Labs;
SELECT 
	person_id as pt_id,
	measurement_concept_id,
	measurement_source_value as lab_textid,
	measurement_date as lab_date,
	value_as_number as lab_num,
	value_source_value as lab_value,
	unit_concept_code as lab_unit,
	range_high,
    range_low
INTO #Labs
FROM omop.cdm_phi.measurement
WHERE measurement_concept_id IN (
	3038553 -- BMI
	, 1616317, 3000963, 3004119, 3006239, 3002173, 46235392, 3027484 -- Hgb all 
	, 3000963 -- Hgb 
	, 3023599, 3024731 -- Mcv
	, 3000905, 3010813 -- Wbc
	, 3024929, 3031586, 3007461 -- Plt 
	, 3019550, 3041473, 3043706 -- Sodium 
	, 3023103, 3043409, 3041354, 3005456 -- Potassium
	, 3014576, 3035285, 3031248, 3018572 -- Chloride
	, 3008152, 3027273, 3015235 -- Bicarbonate
	, 3013682, 3027219, 3004295, 3026617 -- BUN 
	, 3016723, 3051825 -- SCr 
	, 3001420, 3006916 -- Magnesium 
	, 3006906 -- Calcium 
	, 3011904 -- Phosphate 
	, 3013721 -- AST 
	, 3006923 -- ALT 
	, 3035995 -- ALP 
	, 3024128 -- TBili 
	, 3024561 -- Albumin
	, 3020630 -- Total protein 
	, 3019170, 3019762, 3009201 -- TSH 
	, 40765040, 3049536, 3020149, 3027361, 3006615, 3031700 -- Vitamin D 
	, 3022192, 36660413 -- Triglycerides 
	, 3028288, 3009966, 3028437 -- LDL 
	, 3004410 -- HgbA1c 
	, 3007894, 3016100, 3027491, 3023871, 40771569, 3018195, 36304847, 3013139, 3010921, 3011630, 3016410 -- HPylori 
)
AND measurement_date BETWEEN DATEADD(month, -15, '{start_date}') AND '{end_date}' -- restrict to -15 months from encounter date; change me 
AND person_id IN (SELECT pt_id FROM #Demographics)

DROP TABLE IF EXISTS #Hpylori_clean;
SELECT 
    pt_id,
    measurement_concept_id as hpylori_id,
    lab_textid as hpylori_textid,
    lab_date as hpylori_date,
    lab_num as hpylori_num,
    lab_value as hpylori_value,
    lab_unit as hpylori_unit,
    range_high as hpylori_range_high,
    range_low as hpylori_range_low,
    CASE 
        WHEN lab_value = '<9.0' AND range_high = '8.9' THEN 'negative'
        WHEN lab_value = 'Positive' THEN 'positive'
        WHEN lab_value = 'Negative' THEN 'negative'
        WHEN lab_value = 'TNP' THEN 'error' -- test not performed
        WHEN lab_num IS NOT NULL AND lab_num > range_high THEN 'positive'
        WHEN lab_num IS NOT NULL AND lab_num <= range_high THEN 'negative'
        WHEN lab_num IS NOT NULL AND range_high IS NULL THEN 'no range' -- 'H.PYLORI IGG INDEX', 'H. PYLORI IGA', 'H. PYLORI, IGM AB'
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%duplicate%' THEN 'error'
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%equivocal%' THEN 'negative'
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%not sufficient%' THEN 'error'
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%not performed%' THEN 'error'
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%see%' THEN 'error' -- ie. see below or see note
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%no specimen%' THEN 'error'
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%incorrect%' THEN 'error'
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%inappropriate%' THEN 'error'
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%insufficient%' THEN 'error'
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%improper%' THEN 'error'
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%wrong%' THEN 'error'
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%error%' THEN 'error'
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%received%' THEN 'error'
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%cancel%' THEN 'error'
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%inconclusive%' THEN 'error'
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%uncertain%' THEN 'error'
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%comment%' THEN 'error'
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%not offered%' THEN 'error'
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%no longer%' THEN 'error'
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%lost%' THEN 'error'
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%no suitable%' THEN 'error'
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%no longer available%' THEN 'error'
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%lab accident%' THEN 'error'
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%leaked%' THEN 'error'
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%note%' THEN 'error'
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%discrepancy%' THEN 'error'
        ELSE lab_value 
    END AS hpylori_result,
    CASE 
        WHEN lab_value = '<9.0' AND range_high = '8.9' THEN 0
        WHEN lab_value = 'Positive' THEN 1
        WHEN lab_value = 'Negative' THEN 0
        WHEN lab_value = 'TNP' THEN -2 -- test not performed
        WHEN lab_num IS NOT NULL AND lab_num > range_high THEN 1
        WHEN lab_num IS NOT NULL AND lab_num <= range_high THEN 0
        WHEN lab_num IS NOT NULL AND range_high IS NULL THEN -1 -- 'H.PYLORI IGG INDEX', 'H. PYLORI IGA', 'H. PYLORI, IGM AB'
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%duplicate%' THEN -2
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%equivocal%' THEN 0
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%not sufficient%' THEN -2
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%not performed%' THEN -2
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%see%' THEN -2 -- ie. see below or see note
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%no specimen%' THEN -2
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%incorrect%' THEN -2
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%inappropriate%' THEN -2
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%insufficient%' THEN -2
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%improper%' THEN -2
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%wrong%' THEN -2
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%error%' THEN -2
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%received%' THEN -2
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%cancel%' THEN -2
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%inconclusive%' THEN -2
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%uncertain%' THEN -2
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%comment%' THEN -2
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%not offered%' THEN -2
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%no longer%' THEN -2
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%lost%' THEN -2
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%no suitable%' THEN -2
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%no longer available%' THEN -2
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%lab accident%' THEN -2
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%leaked%' THEN -2
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%note%' THEN -2
        WHEN lab_num IS NULL AND LOWER(lab_value) LIKE '%discrepancy%' THEN -2
        ELSE -3 -- if there are a lot of -3s then might be worth the time to go back and clean up the extra values a bit more
    END AS hpylori_result_num,
    CASE 
        WHEN measurement_concept_id IN (3016100, 36304847, 3013139) THEN 'stool'
        WHEN measurement_concept_id IN (3018195, 3016410) THEN 'IgA'
        WHEN measurement_concept_id IN (3007894, 3010921) THEN 'IgM'
        WHEN measurement_concept_id IN (3027491, 3023871, 40771569) THEN 'IgG'
        WHEN measurement_concept_id = 3011630 THEN 'breath'
    END AS hpylori_test
INTO #Hpylori_clean
FROM #Labs

DROP TABLE IF EXISTS #Hpylori_all;
SELECT 
    pt_id,
    hpylori_date,
    hpylori_value,
    hpylori_num,
    hpylori_range_high,
    hpylori_range_low,
    hpylori_result,
    hpylori_result_num,
    hpylori_test,
    ROW_NUMBER() OVER (PARTITION BY pt_id ORDER BY hpylori_result_num DESC, hpylori_date ASC) AS rn,
    ROW_NUMBER() OVER (PARTITION BY pt_id, hpylori_test ORDER BY hpylori_result_num DESC, hpylori_date ASC) AS rn_type
INTO #Hpylori_all
FROM #Hpylori_clean
WHERE hpylori_result_num > -2

DROP TABLE IF EXISTS #Hpylori_earliest;
SELECT 
    pt_id,
    hpylori_date,
    hpylori_value,
    hpylori_num,
    hpylori_range_high,
    hpylori_range_low,
    hpylori_result,
    hpylori_result_num,
    hpylori_test
INTO #Hpylori_earliest
FROM #Hpylori_all
WHERE rn = 1 

DROP TABLE IF EXISTS #Hpylori_type;
SELECT 
    pt_id,
    hpylori_date,
    hpylori_value,
    hpylori_num,
    hpylori_range_high,
    hpylori_range_low,
    hpylori_result,
    hpylori_result_num,
    hpylori_test
INTO #Hpylori_type
FROM #Hpylori_all
WHERE rn_type = 1

DROP TABLE IF EXISTS #Hpylori_pivot;
SELECT 
    e.pt_id,
    MAX(e.hpylori_date) AS hpylori_earliest_date, -- this aggregate function will just select the first since they will all be the same
    MAX(e.hpylori_value) AS hpylori_earliest_value,
    MAX(e.hpylori_range_high) AS hpylori_earliest_range_high,
    MAX(e.hpylori_range_low) AS hpylori_earliest_range_low,
    MAX(e.hpylori_result_num) AS hpylori_earliest_result_num,
    MAX(e.hpylori_test) AS hpylori_earliest_test,
    MAX(CASE WHEN t.hpylori_test = 'stool' THEN t.hpylori_date ELSE NULL END) AS hpylori_stool_date,
    MAX(CASE WHEN t.hpylori_test = 'stool' THEN t.hpylori_value END) AS hpylori_stool_value,
    MAX(CASE WHEN t.hpylori_test = 'stool' THEN t.hpylori_range_high END) AS hpylori_stool_range_high,
    MAX(CASE WHEN t.hpylori_test = 'stool' THEN t.hpylori_range_low END) AS hpylori_stool_range_low,

    MAX(CASE WHEN t.hpylori_test = 'IgA' THEN t.hpylori_date END) AS hpylori_iga_date,
    MAX(CASE WHEN t.hpylori_test = 'IgA' THEN t.hpylori_value END) AS hpylori_iga_value,
    MAX(CASE WHEN t.hpylori_test = 'IgA' THEN t.hpylori_range_high END) AS hpylori_iga_range_high,
    MAX(CASE WHEN t.hpylori_test = 'IgA' THEN t.hpylori_range_low END) AS hpylori_iga_range_low,

    MAX(CASE WHEN t.hpylori_test = 'IgM' THEN t.hpylori_date END) AS hpylori_igm_date,
    MAX(CASE WHEN t.hpylori_test = 'IgM' THEN t.hpylori_value END) AS hpylori_igm_value,
    MAX(CASE WHEN t.hpylori_test = 'IgM' THEN t.hpylori_range_high END) AS hpylori_igm_range_high,
    MAX(CASE WHEN t.hpylori_test = 'IgM' THEN t.hpylori_range_low END) AS hpylori_igm_range_low,

    MAX(CASE WHEN t.hpylori_test = 'IgG' THEN t.hpylori_date END) AS hpylori_igg_date,
    MAX(CASE WHEN t.hpylori_test = 'IgG' THEN t.hpylori_value END) AS hpylori_igg_value,
    MAX(CASE WHEN t.hpylori_test = 'IgG' THEN t.hpylori_range_high END) AS hpylori_igg_range_high,
    MAX(CASE WHEN t.hpylori_test = 'IgG' THEN t.hpylori_range_low END) AS hpylori_igg_range_low,

    MAX(CASE WHEN t.hpylori_test = 'breath' THEN t.hpylori_date END) AS hpylori_breath_date,
    MAX(CASE WHEN t.hpylori_test = 'breath' THEN t.hpylori_value END) AS hpylori_breath_value,
    MAX(CASE WHEN t.hpylori_test = 'breath' THEN t.hpylori_range_high END) AS hpylori_breath_range_high,
    MAX(CASE WHEN t.hpylori_test = 'breath' THEN t.hpylori_range_low END) AS hpylori_breath_range_low
INTO #Hpylori_pivot
FROM #Hpylori_earliest e 
LEFT JOIN #Hpylori_type t 
ON e.pt_id = t.pt_id 
GROUP BY e.pt_id

/* 
 * Generate temporary tables to get baseline and prior data by creating Common Table Expressions.
 */

-- Get all BMIs within 6 months prior to the visit date and order by the value closest to the visit date 
DROP TABLE IF EXISTS #BMI_baseline;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, e.visit_start_date, l.lab_date))) AS rn
INTO #BMI_baseline
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -6, e.visit_start_date) AND e.visit_start_date
	AND l.measurement_concept_id = 3038553

-- Get all BMIs within 9-15 months and order by value closest to 12 months prior
DROP TABLE IF EXISTS #BMI_prior;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, DATEADD(month, -12, e.visit_start_date), l.lab_date))) AS rn 
INTO #BMI_prior
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -15, e.visit_start_date) AND DATEADD(month, -9, e.visit_start_date)
	AND l.measurement_concept_id = 3038553

DROP TABLE IF EXISTS #Hgball_baseline;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, e.visit_start_date, l.lab_date))) AS rn
INTO #Hgball_baseline
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -6, e.visit_start_date) AND e.visit_start_date
	AND l.measurement_concept_id IN (1616317, 3000963, 3004119, 3006239, 3002173, 46235392, 3027484)

DROP TABLE IF EXISTS #Hgball_prior;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, DATEADD(month, -12, e.visit_start_date), l.lab_date))) AS rn 
INTO #Hgball_prior
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -15, e.visit_start_date) AND DATEADD(month, -9, e.visit_start_date)
	AND l.measurement_concept_id IN (1616317, 3000963, 3004119, 3006239, 3002173, 46235392, 3027484)

DROP TABLE IF EXISTS #Hgb_baseline;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, e.visit_start_date, l.lab_date))) AS rn
INTO #Hgb_baseline
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -6, e.visit_start_date) AND e.visit_start_date
	AND l.measurement_concept_id = 3000963

DROP TABLE IF EXISTS #Hgb_prior;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, DATEADD(month, -12, e.visit_start_date), l.lab_date))) AS rn 
INTO #Hgb_prior
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -15, e.visit_start_date) AND DATEADD(month, -9, e.visit_start_date)
	AND l.measurement_concept_id = 3000963

DROP TABLE IF EXISTS #Mcv_baseline;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, e.visit_start_date, l.lab_date))) AS rn
INTO #Mcv_baseline
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -6, e.visit_start_date) AND e.visit_start_date
	AND l.measurement_concept_id IN (3023599, 3024731)

DROP TABLE IF EXISTS #Mcv_prior;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, DATEADD(month, -12, e.visit_start_date), l.lab_date))) AS rn 
INTO #Mcv_prior
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -15, e.visit_start_date) AND DATEADD(month, -9, e.visit_start_date)
	AND l.measurement_concept_id IN (3023599, 3024731)

DROP TABLE IF EXISTS #Wbc_baseline;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, e.visit_start_date, l.lab_date))) AS rn
INTO #Wbc_baseline
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -6, e.visit_start_date) AND e.visit_start_date
	AND l.measurement_concept_id IN (3000905, 3010813)

DROP TABLE IF EXISTS #Wbc_prior;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, DATEADD(month, -12, e.visit_start_date), l.lab_date))) AS rn 
INTO #Wbc_prior
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -15, e.visit_start_date) AND DATEADD(month, -9, e.visit_start_date)
	AND l.measurement_concept_id IN (3000905, 3010813)

DROP TABLE IF EXISTS #Plt_baseline;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, e.visit_start_date, l.lab_date))) AS rn
INTO #Plt_baseline
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -6, e.visit_start_date) AND e.visit_start_date
	AND l.measurement_concept_id IN (3024929, 3031586, 3007461)

DROP TABLE IF EXISTS #Plt_prior;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, DATEADD(month, -12, e.visit_start_date), l.lab_date))) AS rn 
INTO #Plt_prior
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -15, e.visit_start_date) AND DATEADD(month, -9, e.visit_start_date)
	AND l.measurement_concept_id IN (3024929, 3031586, 3007461)

DROP TABLE IF EXISTS #Sodium_baseline;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, e.visit_start_date, l.lab_date))) AS rn
INTO #Sodium_baseline
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -6, e.visit_start_date) AND e.visit_start_date
	AND l.measurement_concept_id IN (3019550, 3041473, 3043706)

DROP TABLE IF EXISTS #Sodium_prior;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, DATEADD(month, -12, e.visit_start_date), l.lab_date))) AS rn 
INTO #Sodium_prior
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -15, e.visit_start_date) AND DATEADD(month, -9, e.visit_start_date)
	AND l.measurement_concept_id IN (3019550, 3041473, 3043706)

DROP TABLE IF EXISTS #Potassium_baseline;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, e.visit_start_date, l.lab_date))) AS rn
INTO #Potassium_baseline
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -6, e.visit_start_date) AND e.visit_start_date
	AND l.measurement_concept_id IN (3023103, 3043409, 3041354, 3005456)

DROP TABLE IF EXISTS #Potassium_prior;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, DATEADD(month, -12, e.visit_start_date), l.lab_date))) AS rn 
INTO #Potassium_prior
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -15, e.visit_start_date) AND DATEADD(month, -9, e.visit_start_date)
	AND l.measurement_concept_id IN (3023103, 3043409, 3041354, 3005456)

DROP TABLE IF EXISTS #Chloride_baseline;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, e.visit_start_date, l.lab_date))) AS rn
INTO #Chloride_baseline
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -6, e.visit_start_date) AND e.visit_start_date
	AND l.measurement_concept_id IN (3014576, 3035285, 3031248, 3018572)

DROP TABLE IF EXISTS #Chloride_prior;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, DATEADD(month, -12, e.visit_start_date), l.lab_date))) AS rn 
INTO #Chloride_prior
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -15, e.visit_start_date) AND DATEADD(month, -9, e.visit_start_date)
	AND l.measurement_concept_id IN (3014576, 3035285, 3031248, 3018572)

DROP TABLE IF EXISTS #Bicarbonate_baseline;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, e.visit_start_date, l.lab_date))) AS rn
INTO #Bicarbonate_baseline
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -6, e.visit_start_date) AND e.visit_start_date
	AND l.measurement_concept_id IN (3008152, 3027273, 3015235)

DROP TABLE IF EXISTS #Bicarbonate_prior;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, DATEADD(month, -12, e.visit_start_date), l.lab_date))) AS rn 
INTO #Bicarbonate_prior
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -15, e.visit_start_date) AND DATEADD(month, -9, e.visit_start_date)
	AND l.measurement_concept_id IN (3008152, 3027273, 3015235)

DROP TABLE IF EXISTS #BUN_baseline;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, e.visit_start_date, l.lab_date))) AS rn
INTO #BUN_baseline
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -6, e.visit_start_date) AND e.visit_start_date
	AND l.measurement_concept_id IN (3013682, 3027219, 3004295, 3026617)

DROP TABLE IF EXISTS #BUN_prior;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, DATEADD(month, -12, e.visit_start_date), l.lab_date))) AS rn 
INTO #BUN_prior
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -15, e.visit_start_date) AND DATEADD(month, -9, e.visit_start_date)
	AND l.measurement_concept_id IN (3013682, 3027219, 3004295, 3026617)

DROP TABLE IF EXISTS #SCr_baseline;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, e.visit_start_date, l.lab_date))) AS rn
INTO #SCr_baseline
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -6, e.visit_start_date) AND e.visit_start_date
	AND l.measurement_concept_id IN (3016723, 3051825)

DROP TABLE IF EXISTS #SCr_prior;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, DATEADD(month, -12, e.visit_start_date), l.lab_date))) AS rn 
INTO #SCr_prior
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -15, e.visit_start_date) AND DATEADD(month, -9, e.visit_start_date)
	AND l.measurement_concept_id IN (3016723, 3051825)

DROP TABLE IF EXISTS #Magnesium_baseline;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, e.visit_start_date, l.lab_date))) AS rn
INTO #Magnesium_baseline
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -6, e.visit_start_date) AND e.visit_start_date
	AND l.measurement_concept_id IN (3001420, 3006916)

DROP TABLE IF EXISTS #Magnesium_prior;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, DATEADD(month, -12, e.visit_start_date), l.lab_date))) AS rn 
INTO #Magnesium_prior
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -15, e.visit_start_date) AND DATEADD(month, -9, e.visit_start_date)
	AND l.measurement_concept_id IN (3001420, 3006916)

DROP TABLE IF EXISTS #Calcium_baseline;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, e.visit_start_date, l.lab_date))) AS rn
INTO #Calcium_baseline
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -6, e.visit_start_date) AND e.visit_start_date
	AND l.measurement_concept_id = 3006906

DROP TABLE IF EXISTS #Calcium_prior;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, DATEADD(month, -12, e.visit_start_date), l.lab_date))) AS rn 
INTO #Calcium_prior
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -15, e.visit_start_date) AND DATEADD(month, -9, e.visit_start_date)
	AND l.measurement_concept_id = 3006906

DROP TABLE IF EXISTS #Phosphate_baseline;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, e.visit_start_date, l.lab_date))) AS rn
INTO #Phosphate_baseline
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -6, e.visit_start_date) AND e.visit_start_date
	AND l.measurement_concept_id = 3011904

DROP TABLE IF EXISTS #Phosphate_prior;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, DATEADD(month, -12, e.visit_start_date), l.lab_date))) AS rn 
INTO #Phosphate_prior
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -15, e.visit_start_date) AND DATEADD(month, -9, e.visit_start_date)
	AND l.measurement_concept_id = 3011904

DROP TABLE IF EXISTS #AST_baseline;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, e.visit_start_date, l.lab_date))) AS rn
INTO #AST_baseline
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -6, e.visit_start_date) AND e.visit_start_date
	AND l.measurement_concept_id = 3013721

DROP TABLE IF EXISTS #AST_prior;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, DATEADD(month, -12, e.visit_start_date), l.lab_date))) AS rn 
INTO #AST_prior
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -15, e.visit_start_date) AND DATEADD(month, -9, e.visit_start_date)
	AND l.measurement_concept_id = 3013721

DROP TABLE IF EXISTS #ALT_baseline;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, e.visit_start_date, l.lab_date))) AS rn
INTO #ALT_baseline
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -6, e.visit_start_date) AND e.visit_start_date
	AND l.measurement_concept_id = 3006923

DROP TABLE IF EXISTS #ALT_prior;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, DATEADD(month, -12, e.visit_start_date), l.lab_date))) AS rn 
INTO #ALT_prior
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -15, e.visit_start_date) AND DATEADD(month, -9, e.visit_start_date)
	AND l.measurement_concept_id = 3006923

DROP TABLE IF EXISTS #ALP_baseline;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, e.visit_start_date, l.lab_date))) AS rn
INTO #ALP_baseline
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -6, e.visit_start_date) AND e.visit_start_date
	AND l.measurement_concept_id = 3035995

DROP TABLE IF EXISTS #ALP_prior;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, DATEADD(month, -12, e.visit_start_date), l.lab_date))) AS rn 
INTO #ALP_prior
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -15, e.visit_start_date) AND DATEADD(month, -9, e.visit_start_date)
	AND l.measurement_concept_id = 3035995

DROP TABLE IF EXISTS #TBili_baseline;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, e.visit_start_date, l.lab_date))) AS rn
INTO #TBili_baseline
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -6, e.visit_start_date) AND e.visit_start_date
	AND l.measurement_concept_id = 3024128

DROP TABLE IF EXISTS #TBili_prior;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, DATEADD(month, -12, e.visit_start_date), l.lab_date))) AS rn 
INTO #TBili_prior
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -15, e.visit_start_date) AND DATEADD(month, -9, e.visit_start_date)
	AND l.measurement_concept_id = 3024128

DROP TABLE IF EXISTS #Albumin_baseline;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, e.visit_start_date, l.lab_date))) AS rn
INTO #Albumin_baseline
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -6, e.visit_start_date) AND e.visit_start_date
	AND l.measurement_concept_id = 3024561

DROP TABLE IF EXISTS #Albumin_prior;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, DATEADD(month, -12, e.visit_start_date), l.lab_date))) AS rn 
INTO #Albumin_prior
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -15, e.visit_start_date) AND DATEADD(month, -9, e.visit_start_date)
	AND l.measurement_concept_id = 3024561

DROP TABLE IF EXISTS #TProtein_baseline;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, e.visit_start_date, l.lab_date))) AS rn
INTO #TProtein_baseline
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -6, e.visit_start_date) AND e.visit_start_date
	AND l.measurement_concept_id = 3020630

DROP TABLE IF EXISTS #TProtein_prior;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, DATEADD(month, -12, e.visit_start_date), l.lab_date))) AS rn 
INTO #TProtein_prior
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -15, e.visit_start_date) AND DATEADD(month, -9, e.visit_start_date)
	AND l.measurement_concept_id = 3020630

DROP TABLE IF EXISTS #TSH_baseline;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, e.visit_start_date, l.lab_date))) AS rn
INTO #TSH_baseline
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -6, e.visit_start_date) AND e.visit_start_date
	AND l.measurement_concept_id IN (3019170, 3019762, 3009201)

DROP TABLE IF EXISTS #TSH_prior;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, DATEADD(month, -12, e.visit_start_date), l.lab_date))) AS rn 
INTO #TSH_prior
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -15, e.visit_start_date) AND DATEADD(month, -9, e.visit_start_date)
	AND l.measurement_concept_id IN (3019170, 3019762, 3009201)

DROP TABLE IF EXISTS #vitD_baseline;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, e.visit_start_date, l.lab_date))) AS rn
INTO #vitD_baseline
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -6, e.visit_start_date) AND e.visit_start_date
	AND l.measurement_concept_id IN (40765040, 3049536, 3020149, 3027361, 3006615, 3031700)

DROP TABLE IF EXISTS #vitD_prior;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, DATEADD(month, -12, e.visit_start_date), l.lab_date))) AS rn 
INTO #vitD_prior
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -15, e.visit_start_date) AND DATEADD(month, -9, e.visit_start_date)
	AND l.measurement_concept_id IN (40765040, 3049536, 3020149, 3027361, 3006615, 3031700)

DROP TABLE IF EXISTS #Triglycerides_baseline;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, e.visit_start_date, l.lab_date))) AS rn
INTO #Triglycerides_baseline
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -6, e.visit_start_date) AND e.visit_start_date
	AND l.measurement_concept_id IN (3022192, 36660413)

DROP TABLE IF EXISTS #Triglycerides_prior;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, DATEADD(month, -12, e.visit_start_date), l.lab_date))) AS rn 
INTO #Triglycerides_prior
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -15, e.visit_start_date) AND DATEADD(month, -9, e.visit_start_date)
	AND l.measurement_concept_id IN (3022192, 36660413)

DROP TABLE IF EXISTS #LDL_baseline;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, e.visit_start_date, l.lab_date))) AS rn
INTO #LDL_baseline
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -6, e.visit_start_date) AND e.visit_start_date
	AND l.measurement_concept_id IN (3028288, 3009966, 3028437)

DROP TABLE IF EXISTS #LDL_prior;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, DATEADD(month, -12, e.visit_start_date), l.lab_date))) AS rn 
INTO #LDL_prior
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -15, e.visit_start_date) AND DATEADD(month, -9, e.visit_start_date)
	AND l.measurement_concept_id IN (3028288, 3009966, 3028437)


DROP TABLE IF EXISTS #Hgba1c_baseline;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, e.visit_start_date, l.lab_date))) AS rn
INTO #Hgba1c_baseline
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -6, e.visit_start_date) AND e.visit_start_date
	AND l.measurement_concept_id = 3004410

DROP TABLE IF EXISTS #Hgba1c_prior;
SELECT e.visit_id,
	e.pt_id,
	e.visit_start_date,
	l.lab_value,
	l.lab_num,
	l.lab_date,
	ROW_NUMBER() OVER (PARTITION BY e.visit_id ORDER BY ABS(DATEDIFF(day, DATEADD(month, -12, e.visit_start_date), l.lab_date))) AS rn 
INTO #Hgba1c_prior
FROM #Encounters e
JOIN #Labs l
	ON e.pt_id = l.pt_id 
	AND l.lab_date BETWEEN DATEADD(month, -15, e.visit_start_date) AND DATEADD(month, -9, e.visit_start_date)
	AND l.measurement_concept_id = 3004410

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
AND person_id IN (SELECT pt_id FROM #Demographics)
AND condition_start_date <= '{end_date}' -- change me to the last encounter date
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
AND person_id IN (SELECT pt_id FROM #Demographics)
AND condition_start_date <= '{end_date}' -- change me to the last encounter date
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
AND person_id IN (SELECT pt_id FROM #Demographics)
AND condition_start_date <= '{end_date}' -- change me to the last encounter date
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
AND person_id IN (SELECT pt_id FROM #Demographics)
AND condition_start_date <= '{end_date}' -- change me to the last encounter date
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
AND person_id IN (SELECT pt_id FROM #Demographics)
AND condition_start_date <= '{end_date}' -- change me to the last encounter date
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
AND person_id IN (SELECT pt_id FROM #Demographics)
AND condition_start_date <= '{end_date}' -- change me to the last encounter date
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
AND person_id IN (SELECT pt_id FROM #Demographics)
AND condition_start_date <= '{end_date}' -- change me to the last encounter date
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
AND person_id IN (SELECT pt_id FROM #Demographics)
AND condition_start_date <= '{end_date}' -- change me to the last encounter date
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
AND person_id IN (SELECT pt_id FROM #Demographics)
AND condition_start_date <= '{end_date}' -- change me to the last encounter date
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
AND person_id IN (SELECT pt_id FROM #Demographics)
AND condition_start_date <= '{end_date}' -- change me to the last encounter date
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
    AND person_id IN (SELECT pt_id FROM #Encounters)
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
        AND person_id IN (SELECT pt_id FROM #Encounters)
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
        AND person_id IN (SELECT pt_id FROM #Encounters)
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
        AND person_id IN (SELECT pt_id FROM #Encounters)
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
    AND observation_date <= '{end_date}' -- change me to the last encounter date
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
    AND observation_date <= '{end_date}' -- change me to the last encounter date
GROUP BY person_id

DROP TABLE IF EXISTS #Social_Smoking_Narrative;
SELECT 
    person_id AS pt_id,
    observation_date AS social_smoking_narrative_date,
    value_as_string AS social_smoking_narrative,
    ROW_NUMBER() OVER (PARTITION BY person_id ORDER BY observation_date DESC) AS rn
INTO #Social_Smoking_Narrative
FROM omop.cdm_phi.observation
WHERE observation_concept_name = 'History of Tobacco use Narrative'
AND observation_date <= '{end_date}' -- change me to the last encounter date

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
    AND person_id IN (SELECT pt_id FROM #Demographics)
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
	d.date_of_death,
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
	b.lab_num AS BMI_baseline,
	b.lab_value AS BMI_baseline_val,
	b.lab_date AS BMI_baseline_date,

	p.lab_num AS BMI_prior,
	p.lab_value AS BMI_prior_val,
	p.lab_date AS BMI_prior_date,

	hab.lab_num AS hgball_baseline,
	hab.lab_value AS hgball_baseline_val,
	hab.lab_date AS hgball_baseline_date,
	
	hap.lab_num AS hgball_prior,
	hap.lab_value AS hgball_prior_val,
	hap.lab_date AS hgball_prior_date,
	
	hb.lab_num AS hgb_baseline,
	hb.lab_value AS hgb_baseline_val,
	hb.lab_date AS hgb_baseline_date,
	
	hp.lab_num AS hgb_prior,
	hp.lab_value AS hgb_prior_val,
	hp.lab_date AS hgb_prior_date,
	
	mb.lab_num AS mcv_baseline,
	mb.lab_value AS mcv_baseline_val,
	mb.lab_date AS mcv_baseline_date,
	
	mp.lab_num AS mcv_prior,
	mp.lab_value AS mcv_prior_val,
	mp.lab_date AS mcv_prior_date,
	
	wb.lab_num AS wbc_baseline,
	wb.lab_value AS wbc_baseline_val,
	wb.lab_date AS wbc_baseline_date,
	
	wp.lab_num AS wbc_prior,
	wp.lab_value AS wbc_prior_val,
	wp.lab_date AS wbc_prior_date,
	
	pb.lab_num AS plt_baseline,
	pb.lab_value AS plt_baseline_val,
	pb.lab_date AS plt_baseline_date,
	
	pp.lab_num AS plt_prior,
	pp.lab_value AS plt_prior_val,
	pp.lab_date AS plt_prior_date,
	
	sb.lab_num AS sodium_baseline,
	sb.lab_value AS sodium_baseline_val,
	sb.lab_date AS sodium_baseline_date,
	
	sp.lab_num AS sodium_prior,
	sp.lab_value AS sodium_prior_val,
	sp.lab_date AS sodium_prior_date,
	
	kb.lab_num AS potassium_baseline,
	kb.lab_value AS potassium_baseline_val,
	kb.lab_date AS potassium_baseline_date,
	
	kp.lab_num AS potassium_prior,
	kp.lab_value AS potassium_prior_val,
	kp.lab_date AS potassium_prior_date,
	
	clb.lab_num AS chloride_baseline,
	clb.lab_value AS chloride_baseline_val,
	clb.lab_date AS chloride_baseline_date,
	
	clp.lab_num AS chloride_prior,
	clp.lab_value AS chloride_prior_val,
	clp.lab_date AS chloride_prior_date,
	
	bicb.lab_num AS bicarbonate_baseline,
	bicb.lab_value AS bicarbonate_baseline_val,
	bicb.lab_date AS bicarbonate_baseline_date,
	
	bicp.lab_num AS bicarbonate_prior,
	bicp.lab_value AS bicarbonate_prior_val,
	bicp.lab_date AS bicarbonate_prior_date,
	
	bunb.lab_num AS bun_baseline,
	bunb.lab_value AS bun_baseline_val,
	bunb.lab_date AS bun_baseline_date,
	
	bunp.lab_num AS bun_prior,
	bunp.lab_value AS bun_prior_val,
	bunp.lab_date AS bun_prior_date,
	
	scrb.lab_num AS scr_baseline,
	scrb.lab_value AS scr_baseline_val,
	scrb.lab_date AS scr_baseline_date,
	
	scrp.lab_num AS scr_prior,
	scrp.lab_value AS scr_prior_val,
	scrp.lab_date AS scr_prior_date,
	
	mgb.lab_num AS magnesium_baseline,
	mgb.lab_value AS magnesium_baseline_val,
	mgb.lab_date AS magnesium_baseline_date,
	
	mgp.lab_num AS magnesium_prior,
	mgp.lab_value AS magnesium_prior_val,
	mgp.lab_date AS magnesium_prior_date,
	
	cb.lab_num AS calcium_baseline,
	cb.lab_value AS calcium_baseline_val,
	cb.lab_date AS calcium_baseline_date,
	
	cp.lab_num AS calcium_prior,
	cp.lab_value AS calcium_prior_val,
	cp.lab_date AS calcium_prior_date,
	
	phb.lab_num AS phosphate_baseline,
	phb.lab_value AS phosphate_baseline_val,
	phb.lab_date AS phosphate_baseline_date,
	
	php.lab_num AS phosphate_prior,
	php.lab_value AS phosphate_prior_val,
	php.lab_date AS phosphate_prior_date,
	
	asb.lab_num AS ast_baseline,
	asb.lab_value AS ast_baseline_val,
	asb.lab_date AS ast_baseline_date,
	
	asp.lab_num AS ast_prior,
	asp.lab_value AS ast_prior_val,
	asp.lab_date AS ast_prior_date,
	
	alb.lab_num AS alt_baseline,
	alb.lab_value AS alt_baseline_val,
	alb.lab_date AS alt_baseline_date,
	
	alp.lab_num AS alt_prior,
	alp.lab_value AS alt_prior_val,
	alp.lab_date AS alt_prior_date,
	
	apb.lab_num AS alp_baseline,
	apb.lab_value AS alp_baseline_val,
	apb.lab_date AS alp_baseline_date,
	
	app.lab_num AS alp_prior,
	app.lab_value AS alp_prior_val,
	app.lab_date AS alp_prior_date,
	
	tbb.lab_num AS tbili_baseline,
	tbb.lab_value AS tbili_baseline_val,
	tbb.lab_date AS tbili_baseline_date,
	
	tbp.lab_num AS tbili_prior,
	tbp.lab_value AS tbili_prior_val,
	tbp.lab_date AS tbili_prior_date,
	
	tpb.lab_num AS tprotein_baseline,
	tpb.lab_value AS tprotein_baseline_val,
	tpb.lab_date AS tprotein_baseline_date,
	
	tpp.lab_num AS tprotein_prior,
	tpp.lab_value AS tprotein_prior_val,
	tpp.lab_date AS tprotein_prior_date,
	
	abb.lab_num AS albumin_baseline,
	abb.lab_value AS albumin_baseline_val,
	abb.lab_date AS albumin_baseline_date,
	
	abp.lab_num AS albumin_prior,
	abp.lab_value AS albumin_prior_val,
	abp.lab_date AS albumin_prior_date,
	
	tsb.lab_num AS tsh_baseline,
	tsb.lab_value AS tsh_baseline_val,
	tsb.lab_date AS tsh_baseline_date,
	
	tsp.lab_num AS tsh_prior,
	tsp.lab_value AS tsh_prior_val,
	tsp.lab_date AS tsh_prior_date,
	
	vb.lab_num AS vitD_baseline,
	vb.lab_value AS vitD_baseline_val,
	vb.lab_date AS vitD_baseline_date,
	
	vp.lab_num AS vitD_prior,
	vp.lab_value AS vitD_prior_val,
	vp.lab_date AS vitD_prior_date,
	
	tb.lab_num AS triglycerides_baseline,
	tb.lab_value AS triglycerides_baseline_val,
	tb.lab_date AS triglycerides_baseline_date,
	
	tp.lab_num AS triglycerides_prior,
	tp.lab_value AS triglycerides_prior_val,
	tp.lab_date AS triglycerides_prior_date,
	
	lb.lab_num AS LDL_baseline,
	lb.lab_value AS LDL_baseline_val,
	lb.lab_date AS LDL_baseline_date,
	
	lp.lab_num AS LDL_prior,
	lp.lab_value AS LDL_prior_val,
	lp.lab_date AS LDL_prior_date,
	
	a1cb.lab_num AS hgba1c_baseline,
	a1cb.lab_value AS hgba1c_baseline_val,
	a1cb.lab_date AS hgba1c_baseline_date,
	
	a1cp.lab_num AS hgba1c_prior,
	a1cp.lab_value AS hgba1c_prior_val,
	a1cp.lab_date AS hgba1c_prior_date,
	
	hpy.hpylori_earliest_date, -- first positive value if there is a positive value
	hpy.hpylori_earliest_value,
	hpy.hpylori_earliest_range_high,
	hpy.hpylori_earliest_range_low,
	hpy.hpylori_earliest_result_num,
	hpy.hpylori_earliest_test,
	hpy.hpylori_stool_date,
	hpy.hpylori_stool_value,
	hpy.hpylori_stool_range_high,
	hpy.hpylori_stool_range_low,
	hpy.hpylori_iga_date,
	hpy.hpylori_iga_value,
	hpy.hpylori_iga_range_high,
	hpy.hpylori_iga_range_low,
	hpy.hpylori_igm_date,
	hpy.hpylori_igm_value,
	hpy.hpylori_igm_range_high,
	hpy.hpylori_igm_range_low,
	hpy.hpylori_igg_date,
	hpy.hpylori_igg_value,
	hpy.hpylori_igg_range_high,
	hpy.hpylori_igg_range_low,
	hpy.hpylori_breath_date,
	hpy.hpylori_breath_value,
	hpy.hpylori_breath_range_high,
	hpy.hpylori_breath_range_low,	

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

LEFT JOIN #Wbc_baseline wb ON e.visit_id = wb.visit_id AND wb.rn=1
LEFT JOIN #Wbc_prior wp ON e.visit_id = wp.visit_id AND wp.rn=1 

LEFT JOIN #Plt_baseline pb ON e.visit_id = pb.visit_id AND pb.rn=1
LEFT JOIN #Plt_prior pp ON e.visit_id = pp.visit_id AND pp.rn=1 

LEFT JOIN #Sodium_baseline sb ON e.visit_id = sb.visit_id AND sb.rn=1
LEFT JOIN #Sodium_prior sp ON e.visit_id = sp.visit_id AND sp.rn=1 

LEFT JOIN #Potassium_baseline kb ON e.visit_id = kb.visit_id AND kb.rn=1
LEFT JOIN #Potassium_prior kp ON e.visit_id = kp.visit_id AND kp.rn=1 

LEFT JOIN #Chloride_baseline clb ON e.visit_id = clb.visit_id AND clb.rn=1
LEFT JOIN #Chloride_prior clp ON e.visit_id = clp.visit_id AND clp.rn=1 

LEFT JOIN #Bicarbonate_baseline bicb ON e.visit_id = bicb.visit_id AND bicb.rn=1
LEFT JOIN #Bicarbonate_prior bicp ON e.visit_id = bicp.visit_id AND bicp.rn=1 

LEFT JOIN #BUN_baseline bunb ON e.visit_id = bunb.visit_id AND bunb.rn=1
LEFT JOIN #BUN_prior bunp ON e.visit_id = bunp.visit_id AND bunp.rn=1 

LEFT JOIN #SCr_baseline scrb ON e.visit_id = scrb.visit_id AND scrb.rn=1
LEFT JOIN #SCr_prior scrp ON e.visit_id = scrp.visit_id AND scrp.rn=1 

LEFT JOIN #Magnesium_baseline mgb ON e.visit_id = mgb.visit_id AND mgb.rn=1
LEFT JOIN #Magnesium_prior mgp ON e.visit_id = mgp.visit_id AND mgp.rn=1 

LEFT JOIN #Calcium_baseline cb ON e.visit_id = cb.visit_id AND cb.rn=1
LEFT JOIN #Calcium_prior cp ON e.visit_id = cp.visit_id AND cp.rn=1 

LEFT JOIN #Phosphate_baseline phb ON e.visit_id = phb.visit_id AND phb.rn=1
LEFT JOIN #Phosphate_prior php ON e.visit_id = php.visit_id AND php.rn=1 

LEFT JOIN #AST_baseline asb ON e.visit_id = asb.visit_id AND asb.rn=1
LEFT JOIN #AST_prior asp ON e.visit_id = asp.visit_id AND asp.rn=1 

LEFT JOIN #ALT_baseline alb ON e.visit_id = alb.visit_id AND alb.rn=1
LEFT JOIN #ALT_prior alp ON e.visit_id = alp.visit_id AND alp.rn=1 

LEFT JOIN #ALP_baseline apb ON e.visit_id = apb.visit_id AND apb.rn=1
LEFT JOIN #ALP_prior app ON e.visit_id = app.visit_id AND app.rn=1 

LEFT JOIN #TBili_baseline tbb ON e.visit_id = tbb.visit_id AND tbb.rn=1
LEFT JOIN #TBili_prior tbp ON e.visit_id = tbp.visit_id AND tbp.rn=1 

LEFT JOIN #TProtein_baseline tpb ON e.visit_id = tpb.visit_id AND tpb.rn=1
LEFT JOIN #TProtein_prior tpp ON e.visit_id = tpp.visit_id AND tpp.rn=1 

LEFT JOIN #Albumin_baseline abb ON e.visit_id = abb.visit_id AND abb.rn=1
LEFT JOIN #Albumin_prior abp ON e.visit_id = abp.visit_id AND abp.rn=1 

LEFT JOIN #TSH_baseline tsb ON e.visit_id = tsb.visit_id AND tsb.rn=1
LEFT JOIN #TSH_prior tsp ON e.visit_id = tsp.visit_id AND tsp.rn=1 

LEFT JOIN #VitD_baseline vb ON e.visit_id = vb.visit_id AND vb.rn=1
LEFT JOIN #VitD_prior vp ON e.visit_id = vp.visit_id AND vp.rn=1 

LEFT JOIN #Triglycerides_baseline tb ON e.visit_id = tb.visit_id AND tb.rn=1
LEFT JOIN #Triglycerides_prior tp ON e.visit_id = tp.visit_id AND tp.rn=1 

LEFT JOIN #LDL_baseline lb ON e.visit_id = lb.visit_id AND lb.rn=1
LEFT JOIN #LDL_prior lp ON e.visit_id = lp.visit_id AND lp.rn=1 

LEFT JOIN #Hgba1c_baseline a1cb ON e.visit_id = a1cb.visit_id AND a1cb.rn=1
LEFT JOIN #Hgba1c_prior a1cp ON e.visit_id = a1cp.visit_id AND a1cp.rn=1 

LEFT JOIN #Hpylori_pivot hpy ON e.pt_id = hpy.pt_id 

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

LEFT JOIN (SELECT * FROM #Social_Language WHERE rn = 1) sl ON e.pt_id = sl.pt_id 
LEFT JOIN (SELECT * FROM #Social_Race WHERE rn = 1) sr ON e.pt_id = sr.pt_id 
LEFT JOIN (SELECT * FROM #Social_Ethnicity WHERE rn = 1) se ON e.pt_id = se.pt_id 
LEFT JOIN (SELECT * FROM #Social_Smoking_Narrative WHERE rn = 1) ssn ON e.pt_id = ssn.pt_id 
LEFT JOIN #Social_Alcohol sa ON e.pt_id = sa.pt_id 
LEFT JOIN #Social_Smoking ss ON e.pt_id = ss.pt_id 

LEFT JOIN #Meds meds ON e.pt_id = meds.pt_id