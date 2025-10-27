
-- Data Cleaning 

-- This query performs essential data cleaning steps on the raw Austin Animal Shelter outcomes data, preparing it for analysis.
 
Steps Undertaken:
1. Handling Missing Data: Replaces NULL names with 'no name' and NULL outcome subtypes with 'unknown'.
2. Standardizing Text: Converts key categorical fields (animal_type,breed, color, etc.) to lowercase and removes leading/trailing whitespace for consistency.
3. Feature Engineering (Age): Calculates a new column, 'age_in_days', by converting the 'age_upon_outcome' string field (e.g., '1 year', '3 months') into a standardized numeric value (in days).
4. Output: Creates the clean, ready-to-use table 'final_animals_data'.



-- ANALYSIS

--Step 1 
-- Calculating the most common species in the shelter

SELECT
  cleaned_animal_type,
  COUNT(*) AS animal_count
FROM
  `crafty-run-441910-f5.austin_animal_shelter_aac.final_animals_data`
GROUP BY
  cleaned_animal_type
ORDER BY
  animal_count DESC
LIMIT 10;



--Step 2
-- Calculating most common breeds in the shelter
SELECT 
  cleaned_breed,
  cleaned_animal_type,
  COUNT(*) AS breed_count
FROM 
  `crafty-run-441910-f5.austin_animal_shelter_aac.final_animals_data` 
GROUP BY
  cleaned_breed,
  cleaned_animal_type
ORDER BY
  breed_count DESC
LIMIT 20;



-- Step 3
-- Calculating the adoption percentage for each species (e.g., Dog, Cat, Other, Livestock).
SELECT
    cleaned_animal_type AS species_name,
    COUNT(animal_id) AS total_count,
    SUM(CASE WHEN cleaned_outcome_type = 'adoption' THEN 1 ELSE 0 END) AS adopted_count,
    ROUND(CAST(SUM(CASE WHEN cleaned_outcome_type = 'adoption' THEN 1 ELSE 0 END) AS FLOAT64) * 100 / COUNT(animal_id), 2) AS adoption_percentage
FROM
    crafty-run-441910-f5.austin_animal_shelter_aac.final_animals_data

GROUP BY 1
HAVING total_count > 100
ORDER BY
    adoption_percentage DESC;



-- Step 4
--Calculating breed adoption percentage
SELECT
    cleaned_breed AS breed_name,
    cleaned_animal_type AS species_name, 
    COUNT(animal_id) AS total_count,
    SUM(CASE WHEN cleaned_outcome_type = 'adoption' THEN 1 ELSE 0 END) AS adopted_count,
    -- Calculate percentage: (Adopted Count / Total Count) * 100
    ROUND(CAST(SUM(CASE WHEN cleaned_outcome_type = 'adoption' THEN 1 ELSE 0 END) AS FLOAT64) * 100 / COUNT(animal_id), 2) AS adoption_percentage
FROM
    crafty-run-441910-f5.austin_animal_shelter_aac.final_animals_data
GROUP BY 1, 2 
HAVING total_count > 100 
ORDER BY
    adoption_percentage DESC;



--Step 5
-- Calculating the actual adoption rate for animals based in sterilization status 
WITH CategorizedOutcomes AS (
    -- Step A: Categorize the sterilization status based on the 6 distinct values.
    SELECT
        animal_id,
        cleaned_outcome_type,
        CASE
            WHEN cleaned_sex_upon_outcome IN ('spayed female', 'neutered male') THEN 'Spayed/Neutered'
            WHEN cleaned_sex_upon_outcome IN ('intact female', 'intact male') THEN 'Intact'
            WHEN cleaned_sex_upon_outcome = 'unknown' OR cleaned_sex_upon_outcome IS NULL THEN 'Unknown/NULL Status'
            ELSE 'ERROR_STATUS' 
        END AS sterilization_status,
        CASE
            WHEN cleaned_outcome_type = 'adoption' THEN 1
            ELSE 0
        END AS is_adopted
    FROM
        crafty-run-441910-f5.austin_animal_shelter_aac.final_animals_data
),
AdoptionMetrics AS (
    -- Step B: Calculate the total count and the adoption count for each status group.
    SELECT
        sterilization_status,
        COUNT(animal_id) AS total_animals_in_category,
        SUM(is_adopted) AS adopted_animals_in_category
    FROM
        CategorizedOutcomes
    WHERE
        sterilization_status != 'ERROR_STATUS'
    GROUP BY
        sterilization_status
)
SELECT
    sterilization_status,
    total_animals_in_category AS Total_Animals,
    adopted_animals_in_category AS Adopted_Animals,
    
    ROUND(CAST(adopted_animals_in_category AS FLOAT64) * 100 / total_animals_in_category, 2) AS adoption_percentage
FROM
    AdoptionMetrics
ORDER BY
    adopted_animals_in_category DESC;



--Step 6
--Calculating adoption rate by age
SELECT
    cleaned_animal_type AS species_name,
    CASE
        -- Using age_days divided by 365.25 to calculate approximate years
        WHEN age_in_days IS NULL THEN 'Unknown Age'
        WHEN (age_in_days / 365.25) <= 0.5 THEN 'Infant (0-6 Months)'
        WHEN (age_in_days / 365.25) <= 2 THEN 'Young (6M-2Y)'        
        WHEN (age_in_days / 365.25) <= 7 THEN 'Adult (2Y-7Y)'        
        ELSE 'Senior (> 7 Years)'                            
    END AS age_group,
    COUNT(animal_id) AS total_count,
    SUM(CASE WHEN cleaned_outcome_type = 'adoption' THEN 1 ELSE 0 END) AS adopted_count,
    -- Calculating adoption percentage for specific species and age group
    ROUND(CAST(SUM(CASE WHEN cleaned_outcome_type = 'adoption' THEN 1 ELSE 0 END) AS FLOAT64) * 100 / COUNT(animal_id), 2) AS adoption_percentage
FROM
    crafty-run-441910-f5.austin_animal_shelter_aac.final_animals_data
GROUP BY 1, 2
HAVING total_count > 50 
ORDER BY
    species_name, 
    CASE 
        WHEN age_group = 'Infant (0-6 Months)' THEN 1
        WHEN age_group = 'Young (6M-2Y)' THEN 2
        WHEN age_group = 'Adult (2Y-7Y)' THEN 3
        WHEN age_group = 'Senior (> 7 Years)' THEN 4
        ELSE 5
    END;



--Step 7
-- Extracting month name from datetime_timestamp
SELECT
    datetime,
    datetime AS datetime_timestamp,
    FORMAT_DATE('%Y-%m', datetime) AS year_month_label,
    FORMAT_DATE('%B', datetime) AS month_name
FROM
    crafty-run-441910-f5.austin_animal_shelter_aac.final_animals_data
;



--Step 8
--Calculating monthly adoption rates
SELECT
    FORMAT_DATE('%m', datetime) AS month_number,
    FORMAT_DATE('%B', datetime) AS month_name,
    
-- Suming up ALL outcomes for this specific month across ALL years
    COUNT(t1.animal_id) AS total_outcomes_cumulative,
    
-- Suming up ALL adoptions for this specific month across ALL years
    COUNTIF(t1.cleaned_outcome_type = 'adoption') AS total_adoptions_cumulative,
    
-- Calculating the overall average Adoption Percentage for this month
    SAFE_DIVIDE(
        COUNTIF(t1.cleaned_outcome_type = 'adoption') * 100.0, 
        COUNT(t1.animal_id)
    ) AS cumulative_adoption_percentage
FROM
    crafty-run-441910-f5.austin_animal_shelter_aac.final_animals_data AS t1
GROUP BY 
    month_number, 
    month_name
ORDER BY 
    month_number ASC;


--Step 9
-- Calculating the percentage of animals that resulted in a 'euthanasia' outcome,
SELECT
    cleaned_animal_type AS species_name,
    COUNT(animal_id) AS total_count,
    SUM(CASE WHEN cleaned_outcome_type = 'euthanasia' THEN 1 ELSE 0 END) AS euthanasia_count,
    ROUND(CAST(SUM(CASE WHEN cleaned_outcome_type = 'euthanasia' THEN 1 ELSE 0 END) AS FLOAT64) * 100 / COUNT(animal_id), 2) AS euthanasia_percentage
FROM
    crafty-run-441910-f5.austin_animal_shelter_aac.final_animals_data
GROUP BY 1
HAVING total_count > 50 
ORDER BY euthanasia_percentage DESC;




-- Step 10
-- Comparing two key successful outcomes (RTO and Adoption) across different species 
SELECT
    t1.cleaned_animal_type AS species,
    COUNT(t1.animal_id) AS total_outcomes,
    COUNTIF(t1.cleaned_outcome_type = 'adoption') AS adoption_count,
    ROUND( 
        SAFE_DIVIDE(
            COUNTIF(t1.cleaned_outcome_type = 'adoption') * 100.0, 
            COUNT(t1.animal_id)
        ), 2
    ) AS adoption_rate,
    
    COUNTIF(t1.cleaned_outcome_type = 'return to owner' OR t1.cleaned_outcome_type = 'rto-adopt') AS rto_count,
    ROUND( 
        SAFE_DIVIDE(
            COUNTIF(t1.cleaned_outcome_type = 'return to owner' OR t1.cleaned_outcome_type = 'rto-adopt') * 100.0, 
            COUNT(t1.animal_id)
        ), 2
    ) AS rto_rate
FROM
    crafty-run-441910-f5.austin_animal_shelter_aac.final_animals_data AS t1
GROUP BY 
    species
ORDER BY 
    total_outcomes DESC;

