-- Look for the all concept codes that match a regex. 
-- Maps Epic LRR lab component codes to LOINC Athena concept codes 
-- measurement_source_concept_id == Epic concept ID
-- measurement_concept_id == LOINC athena concept ID 
DROP TABLE IF EXISTS #LabConcept_Map;
SELECT 
	lrr.vocabulary_id AS lrr_vocabulary_id
	,lrr.concept_id AS measurement_source_concept_id
	,lrr.concept_code AS lrr_concept_code
	,lrr.concept_name AS lrr_concept_name
	,map.relationship_id
	,athena.vocabulary_id AS loinc_vocabulary_id
	,athena.concept_id AS measurement_concept_id
	,athena.concept_code AS loinc_concept_code
	,athena.concept_name AS loinc_concept_name
INTO #LabConcept_Map
FROM omop.cdm_phi.concept_relationship map
INNER JOIN omop.cdm_phi.concept lrr
	ON map.concept_id_1 = lrr.concept_id AND lrr.vocabulary_id = 'EPIC LRR .1'
INNER JOIN omop.cdm_phi.concept athena
	ON map.concept_id_2 = athena.concept_id	AND map.relationship_id = N'Maps to'
-- CHANGE ME 
WHERE (lrr.concept_name LIKE '%total%bilirubin%' -- OR lrr.concept_name LIKE '%bilirubin%total%'
OR athena.concept_name LIKE '%total%bilirubin%' -- OR athena.concept_name LIKE '%bilirubin%total%'
)

-- Count the frequency to determine the fields that are most populated.
-- Manually filter through the measurement names and concept names to select the concept IDs of interest 
-- During this project, we selected based on LOINC 
SELECT
	m.measurement_concept_id
	,m.measurement_source_value
	,count_big(*) AS row_count
	,loinc.loinc_concept_name
	-- ,lrr.lrr_concept_namea
FROM omop.cdm_phi.measurement m
INNER JOIN #LabConcept_Map loinc ON m.measurement_concept_id = loinc.measurement_concept_id
-- INNER JOIN #LabConcept_Map lrr ON m.measurement_source_concept_id = lrr.measurement_source_concept_id
-- WHERE m.measurement_concept_id IN (SELECT DISTINCT measurement_concept_id FROM #LabConcept_Map)
GROUP BY m.measurement_concept_id, m.measurement_source_value, loinc.loinc_concept_name --, lrr.lrr_concept_name
ORDER BY count_big(*) DESC