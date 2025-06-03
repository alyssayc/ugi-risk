import pandas as pd
import numpy as np
import seaborn as sns
import matplotlib.pyplot as plt
from pathlib import Path
import json
from datetime import datetime
import argparse 
import utils 

def apply_exclusion_criteria(data_dir, file_list, ugi_file, consort_diagram_numbers_filename):
    list_chunks = [] # To store the list of data chunks

    # Keep track of number of encounters and unique patients 
    num_enc_incl = 0
    pts_incl = set()
    num_enc_excl_age = 0

    for filename in file_list:
        df_chunk = pd.read_csv(data_dir / filename, low_memory=False)[utils.COLNAMES_COHORT]
        print(f'{filename}: {df_chunk.shape}')

        # Update numbers 
        num_enc_incl += df_chunk.shape[0]
        pts_incl.update(df_chunk.pt_id)

        # Apply screening age exclusion criteria 
        excl_age = (df_chunk.age < 40) | (df_chunk.age > 85) # Pts not within proposed screening age of 40-85 
        num_enc_excl_age += int(excl_age.sum())
        list_chunks.append(df_chunk[~excl_age]) 

    # Merge the data chunks together in one dataframe
    df_chunks = pd.concat(list_chunks, ignore_index=True)

    # Apply multiple encounters exclusion criteria 
    df_patients = df_chunks.sort_values(by='visit_start_date').drop_duplicates(subset='pt_id', keep='first')
    num_enc_excl_duplicates = df_chunks.shape[0] - df_patients.shape[0]
    num_pt_excl_duplicates = df_chunks.pt_id.nunique() - df_patients.pt_id.nunique()

    # Calculate BMI based on height and weight
    bmi_series = utils.calculate_bmi(df_patients['height_baseline'], df_patients['weight_baseline'])
    df_patients = pd.concat([df_patients, pd.DataFrame({'BMI_baseline_all': bmi_series})], axis=1)

    # Count and calculate the percentage of non-null values
    columns = ["height_baseline", "weight_baseline", "BMI_baseline", 'BMI_baseline_all']
    non_null_counts = df_patients[columns].notnull().sum()
    non_null_percentages = (non_null_counts / len(df_patients)) * 100

    summary = pd.DataFrame({
        "non_null_count": non_null_counts,
        "non_null_percent": non_null_percentages.round(2)
    })
    print(summary)

    # Read UGI cancer registry data 
    df_ugi = pd.read_csv(data_dir / ugi_file, low_memory=False) #, index_col = False)

    # Select the first UGI cancer diagnosis by date for patients with multiple UGI cancers 
    df_ugi_first = df_ugi.sort_values(by='datetime_dx').drop_duplicates(subset='mrn', keep='first')

    # Merge UGI registry with extracted Epic data 
    df_merged = df_patients.merge(df_ugi_first, on='mrn', how='left')

    print(f'Number of patients in registry without matching MRN: {df_ugi_first.shape[0] - df_merged.datetime_dx.notnull().sum()}')
    print(f'Number of patients in registry with matching MRN: {int(((df_merged.pt_id.notnull()) & df_merged.datetime_dx.notnull()).sum())}')

    # Convert to datetime 
    date_vars = ['visit_start_date', 'datetime_dx', 'date_of_death']
    for date_var in date_vars: 
        df_merged[date_var] = pd.to_datetime(df_merged[date_var], errors='coerce')

    # Define exclusion criteria 
    excl_dx_before_visit = (df_merged.visit_start_date > df_merged.datetime_dx) # Pts whose UGI cancer diagnosis occured before the visit date
    excl_dx_soon_after_visit = ((df_merged.datetime_dx >= df_merged.visit_start_date) & (df_merged.datetime_dx < (df_merged.visit_start_date + pd.DateOffset(months=12)))) # Pts whose UGI cancer diagnosis occured less than 12 months after the visit date
    excl_gastrichx = (df_merged.gastricca == 1.0) & (df_merged.primary_tumor_site.isna()) # Pts who had a hx of gastric cancer as part of their PMHx but not included in the registry
    excl_esophagealhx = (df_merged.esophagealca == 1.0) & (df_merged.primary_tumor_site.isna()) # Pts who had a hx of esophageal cancer as part of their PMHx but not included in the registry
    excl_otherugicahx = (df_merged.ugica_other == 1) # Pts who were in the registry for other UGI cancer 
    excl_death = ((df_merged.date_of_death.notnull()) & (df_merged.visit_start_date >= df_merged.date_of_death)) # Pts whose death date is documented as prior to or day of encounter date
    excl_missing_mrn = ((df_merged.mrn.isna()) | (df_merged.mrn == "<>"))
    # excl_bmi_missing = (df_merged.BMI_baseline_all.isna()) # Pts who has missing BMI, aka not seen in person for the last 6 months 

    # Calculate number of pts excluded
    num_pt_excl_age = len(pts_incl) - df_chunks.pt_id.nunique()
    num_pt_excl_dx_before_visit = excl_dx_before_visit.sum()
    num_pt_excl_dx_soon_after_visit = excl_dx_soon_after_visit.sum()
    num_pt_excl_gastrichx = excl_gastrichx.sum()
    num_pt_excl_esophagealhx = excl_esophagealhx.sum()
    num_pt_excl_otherugicahx = excl_otherugicahx.sum()
    num_pt_excl_death = excl_death.sum()
    num_pt_excl_missing_mrn = excl_missing_mrn.sum()
    # num_pt_excl_bmi_missing = excl_bmi_missing.sum()

    # Apply exclusion criteria 
    df_cohort = df_merged[~(excl_dx_before_visit | excl_dx_soon_after_visit | excl_gastrichx | excl_esophagealhx | excl_otherugicahx | excl_death | excl_missing_mrn)]

    # Total (non-sequential) exclusion numbers for cohort
    output = (
        f'Total encounters: {num_enc_incl}, total patients: {len(pts_incl)}\n'
        f'Excluded - outside screening age: {num_enc_excl_age} encounters, {num_pt_excl_age} pts\n'
        f'Excluded - multiple encounters: {num_enc_excl_duplicates} encounters, {num_pt_excl_duplicates} pts\n'
        f'Excluded - UGI cancer dx before visit: {num_pt_excl_dx_before_visit} patients\n'
        f'Excluded - UGI cancer dx soon after visit: {num_pt_excl_dx_soon_after_visit} patients\n'
        f'Excluded - gastric ca hx not confirmed: {num_pt_excl_gastrichx} patients\n'
        f'Excluded - esophageal ca hx not confirmed: {num_pt_excl_esophagealhx} patients\n'
        f'Excluded - other UGI cancer subtype: {num_pt_excl_otherugicahx} patients\n'
        f'Excluded - death prior to enc: {num_pt_excl_death} patients\n'
        f'Excluded - missing mrn: {num_pt_excl_missing_mrn} patients\n'
        #f'Excluded - BMI missing: {num_pt_excl_bmi_missing} patients\n'
        f'Cohort: {df_cohort.shape[0]} encounters, {df_cohort.pt_id.nunique()} patients\n'
    )

    print(output)

    # Write the output string to a file
    with open(data_dir / consort_diagram_numbers_filename, "w") as file:
        file.write(output)

    # Investigate which UGI cases are being excluded and why 
    # Merge UGI registry with necessary Epic data
    df_ugi_exclusions = df_ugi.merge(df_patients, on='mrn', how='left')

    # Convert to datetime 
    date_vars = ['visit_start_date', 'datetime_dx', 'date_of_death']
    for date_var in date_vars: 
        df_ugi_exclusions[date_var] = pd.to_datetime(df_ugi_exclusions[date_var], errors='coerce')

    df_ugi_exclusions['excl_dx_before_visit'] = (df_ugi_exclusions.visit_start_date > df_ugi_exclusions.datetime_dx) # Pts whose UGI cancer diagnosis occured before the visit date
    df_ugi_exclusions['excl_dx_soon_after_visit'] = ((df_ugi_exclusions.datetime_dx >= df_ugi_exclusions.visit_start_date) & (df_ugi_exclusions.datetime_dx < (df_ugi_exclusions.visit_start_date + pd.DateOffset(months=12)))) # Pts whose UGI cancer diagnosis occured less than 12 months after the visit date
    df_ugi_exclusions['excl_gastrichx'] = (df_ugi_exclusions.gastricca == 1.0) & (df_ugi_exclusions.primary_tumor_site.isna()).astype(int) # Pts who had a hx of gastric cancer as part of their PMHx but not included in the registry
    df_ugi_exclusions['excl_esophagealhx'] = (df_ugi_exclusions.esophagealca == 1.0) & (df_ugi_exclusions.primary_tumor_site.isna()).astype(int) # Pts who had a hx of esophageal cancer as part of their PMHx but not included in the registry
    df_ugi_exclusions['excl_otherugicahx'] = (df_ugi_exclusions.ugica_other == 1).astype(int) # Pts who were in the registry for other UGI cancer 
    df_ugi_exclusions['excl_death'] = ((df_ugi_exclusions.date_of_death.notnull()) & (df_ugi_exclusions.visit_start_date >= df_ugi_exclusions.date_of_death)) # Pts whose death date is documented as prior to or day of encounter date

    # Save the UGI data with the exclusion criteria 
    df_ugi_exclusions.to_csv(data_dir / "ugicancer_registry_exclusion.csv")

    return df_cohort

def clean_data(df):
    df.visit_start_date = pd.to_datetime(df.visit_start_date)
    df.datetime_dx = pd.to_datetime(df.datetime_dx)
    df.date_of_death = pd.to_datetime(df.date_of_death, format='mixed')

    # Extract year from visit dates
    df['visit_year'] = df.visit_start_date.dt.year
    df['diagnosis_year'] = df.datetime_dx.dt.year
    df['death_year'] = df.date_of_death.dt.year

    # Create two variables per categorical var for easier data processing later
    # var_missing will have nulls, var will have "No matching concept"
    df['sex_missing'] = np.where(df.sex == "No matching concept", np.nan, df.sex) 
    # df['sex_clean_missing'] = np.where(df.sex_clean == "No matching concept", np.nan, df.sex_clean) 
    df['ethnicity_missing'] = np.where(df.ethnicity == "No matching concept", np.nan, df.ethnicity) 

    # Clean up race variable 
    df['race_clean'] = df.race.str.lower().map(utils.RACE_DICT)
    df['race_clean'] = df['race_clean'].apply(lambda x: "No matching concept" if pd.isna(x) else x)
    df['race_clean_missing'] = np.where(df.race_clean == "No matching concept", np.nan, df.race_clean)

    # Create H pylori variables
    # Active = only stool and breath testing
    # Chronic = all testing including other serologies and PMHx 
    # var_missing will have nulls, var will have "No matching concept"

    df['hpylori_active_missing'] = df.apply(utils.clean_hpylori, axis=1) # Only stool and breath testing
    df['hpylori_active_chronic_missing'] = df.apply(utils.clean_hpylori_serology, axis=1) # Incorporate Hpylori serology and PMHx

    df['hpylori_active'] = df['hpylori_active_missing'].apply(lambda x: "No matching concept" if pd.isna(x) else x)
    df['hpylori_active_chronic'] = df['hpylori_active_chronic_missing'].apply(lambda x: "No matching concept" if pd.isna(x) else x)
    df['hpylori_active_chronic_binary'] = df['hpylori_active_chronic_missing'].apply(lambda x: 1 if x == 1 else 0) # assume H pylori is negative if testing does not exist (null)

    # Create a comprehensive tobacco and alcohol variable by merging data obtained from PMHx and social history.
    df['tobacco_all'] = df[['tobacco', 'social_smoking_ever']].max(axis=1)
    df['tobacco_all'] = df['tobacco_all'].apply(lambda x: "No matching concept" if pd.isna(x) or x ==- 1 else x)
    df['alcohol_all'] = df[['alcohol', 'social_alcohol']].max(axis=1)
    df['alcohol_all'] = df['alcohol_all'].apply(lambda x: "No matching concept" if pd.isna(x) or x ==- 1 else x)

    # Create additional vars for alcohol and tobacco to analyze 
    df['alcohol_all_missing'] = df['alcohol_all'].apply(lambda x: np.nan if x == "No matching concept" else x)
    df['alcohol_binary_missing'] = df['alcohol_all_missing'].apply(lambda x: 1 if x == 2 else x)
    df['alcohol_binary'] = df['alcohol_all'].apply(lambda x: 1 if x in [1,2] else 0)

    df['tobacco_all_missing'] = df['tobacco_all'].apply(lambda x: np.nan if x == "No matching concept" else x)
    df['tobacco_binary_missing'] = df['tobacco_all_missing'].apply(lambda x: 1 if x == 2 else x)
    df['tobacco_binary'] = df['tobacco_all'].apply(lambda x: 1 if x in [1,2] else 0)

    # Make PMHx and FMHx binary 
    df['hnca'] = df['hnca'].apply(lambda x: 1 if x == 1 else 0)
    df['achalasia'] = df['achalasia'].apply(lambda x: 1 if x == 1 else 0)
    df['pud'] = df['pud'].apply(lambda x: 1 if x == 1 else 0)
    df['gerd'] = df['gerd'].apply(lambda x: 1 if x == 1 else 0)
    df['barretts'] = df['barretts'].apply(lambda x: 1 if x == 1 else 0)
    df['cad'] = df['cad'].apply(lambda x: 1 if x == 1 else 0)
    df['famhx_cancer'] = df['famhx_cancer'].apply(lambda x: 1 if x == 1 else 0)
    df['famhx_gastricca'] = df['famhx_gastricca'].apply(lambda x: 1 if x == 1 else 0)
    df['famhx_esophagealca'] = df['famhx_esophagealca'].apply(lambda x: 1 if x == 1 else 0)
    df['famhx_colonca'] = df['famhx_colonca'].apply(lambda x: 1 if x == 1 else 0)
    df['famhx_barretts'] = df['famhx_barretts'].apply(lambda x: 1 if x == 1 else 0)

    # Categorize medication use date
    df['PPI'] = df['PPI_start_date'].notna().astype(int)
    df['ASA'] = df['ASA_start_date'].notna().astype(int)
    df['NSAID'] = df['NSAID_start_date'].notna().astype(int)

    # Impute hemoglobin 
    hgball_mean = df.hgb_baseline.mean()
    df['hgball_baseline_imputed_mean'] = np.where(df.hgball_baseline.isna(), hgball_mean, df.hgball_baseline)

    # Create column for all UGI cancers together (stomach and esophagus)
    df['ugica'] = df[['ugica_ESCC', 'ugica_EAC', 'ugica_CGC', 'ugica_NCGC']].max(axis=1)
    df.loc[df.ugica.isna(), 'ugica'] = 0
    df['subtype'] = np.where(df.subtype.isna(), "None", df.subtype)

    # Create other outcome variables 
    df['death'] = df.death_year.notna().astype(int)
    
    # Calculate the days between visit_start_date and datetime_dx, and visit_start_date and date_of_death
    df['days_to_dx'] = (df['datetime_dx'] - df['visit_start_date']).dt.days
    df['days_to_death'] = (df['date_of_death'] - df['visit_start_date']).dt.days
    
    # Calculate months_to_dx based on days_to_dx
    df['months_to_dx'] = df['days_to_dx'] / 30.4375

    # Create the days_to_event column as the minimum of days_to_dx and days_to_death
    end_of_study = datetime(2023, 12, 31) # Define the end of the study period
    df['days_follow_up'] = (end_of_study - df['visit_start_date']).dt.days
    df['days_to_event'] = df[['days_to_dx', 'days_to_death', 'days_follow_up']].min(axis=1)
    df['months_to_event'] = df['days_to_event'] / 30.4375

    return df 

def parse_args(): 
    # Set up command-line argument parsing 
    parser = argparse.ArgumentParser(description="Create the cohort by applying inclusion and exclusion criteria to data file and merge to UGI registry data.")

    # Add arguments
    parser.add_argument(
        '--data_txt_file', 
        type=str, 
        required=True, 
        help='Path to text file listing all batched data CSV files'
    )
    
    parser.add_argument(
        '--ugi_file', 
        type=str, 
        required=True, 
        help='Path to the UGI cancer registry file (CSV format)'
    )
    
    return parser.parse_args()

def main(): 
    # Parse the arguments
    args = parse_args()

    # Define directory path variable
    data_dir = Path('./../data/')

    # Define data filenames
    data_txt_file = "all_data_files.txt" 
    ugi_file = "ugicancer_registry_clean.csv"

    # Filenames to be saved as 
    today_date = datetime.now().strftime('%Y%m%d') # Get today's date
    consort_diagram_numbers_filename = f"consort_diagram_numbers_{today_date}.txt"
    final_data_file = f'cleaned_cohort_{today_date}.csv'

    # Get the data filenames
    file_list = []
    with open(data_dir / data_txt_file, 'r') as file:
        file_list = [line.strip() for line in file if line.strip()]

    # Apply exclusion criteria 
    df_cohort = apply_exclusion_criteria(data_dir, file_list, ugi_file, consort_diagram_numbers_filename)

    # Clean cohort and define new variables 
    df_clean = clean_data(df_cohort.copy())

    # Save final cleaned cohort data
    df_clean.to_csv(data_dir / final_data_file)

if __name__ == "__main__":
    main()