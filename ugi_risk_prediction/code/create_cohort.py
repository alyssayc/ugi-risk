import pandas as pd
import numpy as np
import seaborn as sns
import matplotlib.pyplot as plt
from pathlib import Path
from tableone import TableOne, load_dataset
import dask.dataframe as dd
import json
from datetime import datetime
import argparse 
import utils 

def apply_inclusion_criteria(data_dir, data_txt_file):
    all_mrns = set() # Running count of all MRNs 
    cohort_mrns = set() # Running count of all MRNs included in cohort
    past_encs = {} # Dict to store visit start dates for each MRN 
    cohort = [] # List to accumulate rows for the cohort DataFrame 

    # Date variables to convert to datetime
    date_variables = ['visit_start_date', 'visit_start_date_minus_18mo', 'visit_start_date_minus_6mo', 'gastricca_start_date', 'esophagealca_start_date']

    with open(data_dir / data_txt_file, 'r') as file:
        file_list = [line.strip() for line in file if line.strip()]

        for filename in file_list:
            df_chunk = pd.read_csv(data_dir / filename, low_memory=False)
            print(f'{filename}: {df_chunk.shape}')
            
            # Set the column names for the final dataframe - only need to do this once 
            if len(cohort_cols) == 0:
                cohort_cols = df_chunk.columns  

            # Create a running set of all MRNs that met the study period 
            all_mrns.update(set(df_chunk.mrn))

            # Sort from earliest to latest date because the algorithm will check to see if there was a prior encounter 
            df_chunk.sort_values(by='visit_start_date', ascending=True, inplace=True) 

            # Convert to datetime objects
            for date_col in date_variables:
                # Print the number of nulls before and after converting to see if there are errors with conversion.
                # coercing errors forces values that are not datetime into null.
                print(f'Number of nulls before converting: {df_chunk[date_col].isna().sum()}')
                df_chunk[date_col] = pd.to_datetime(df_chunk[date_col], errors='coerce') 
                print(f'Number of nulls after converting: {df_chunk[date_col].isna().sum()}')

            # Brute force through each patient and apply inclusion criteria
            # Inclusion criteria - Age 40-85 and has a prior encounter
            for idx, row in df_chunk.iterrows():
                mrn = row.mrn
                age = row.age
                visit_start_date = row.visit_start_date

                if mrn in cohort_mrns: # If MRN is already included, then not first encounter pair so exclude 
                    continue
                elif mrn in past_encs and age >= 40 and age <= 85: # Include first encounter pair 
                    cohort.append(row)
                    cohort_mrns.add(mrn)
                else: # First encounter for this mrn 
                    past_encs[mrn] = [visit_start_date]
    
    print('Applying inclusion criteria')
    print(f'Total MRNs: {len(all_mrns)}\nMRNs that meet inclusion criteria: {len(cohort_mrns)}')

    # Turn into a dataframe 
    return pd.DataFrame(cohort, columns=cohort_cols)

def apply_exclusion_critera(df_merged):
    # Define exclusion criteria 
    # excl_age = (df_merged.age < 40) | (df_merged.age > 85) # Pts not within proposed screening age of 40-85 
    excl_dx_before_visit = (df_merged.visit_start_date > df_merged.datetime_dx) # Pts whose UGI cancer diagnosis occured before the visit date
    excl_gastrichx = (df_merged.gastricca == 1.0) & (df_merged.primary_tumor_site.isna()) # Pts who had a hx of gastric cancer as part of their PMHx but not included in the registry
    excl_esophagealhx = (df_merged.esophagealca == 1.0) & (df_merged.primary_tumor_site.isna()) # Pts who had a hx of esophageal cancer as part of their PMHx but not included in the registry

    # Calculate number excluded 
    num_incl = df_merged.shape[0]
    # num_excl_age = excl_age.sum()
    num_excl_dx_before_visit = excl_dx_before_visit.sum()
    num_excl_gastrichx = excl_gastrichx.sum()
    num_excl_esophagealhx = excl_esophagealhx.sum()

    print('Applying exclusion criteria')
    # Print out the number of excluded rows for each criterion
    print(f"Included: {num_incl}")
    # num_incl -= num_excl_age
    # print(f"Excluded due to age: -{num_excl_age} = {num_incl}")
    num_incl -= num_excl_dx_before_visit
    print(f"Excluded due to diagnosis before visit: -{num_excl_dx_before_visit} = {num_incl}")
    num_incl = num_incl - num_excl_gastrichx - num_excl_esophagealhx
    print(f"Excluded due to UGI cancer history: -{num_excl_gastrichx+num_excl_esophagealhx} = {num_incl}")

    # Apply exclusion criteria
    df_cohort = df_merged[~(excl_dx_before_visit | excl_gastrichx | excl_esophagealhx)]
    remaining_shape = df_cohort.shape
    print(f"Remaining rows after applying all exclusions (note one pt can meet multiple criteria): {remaining_shape[0]}")

    return df_cohort

def clean_data(df):
    # Extract year from visit dates
    df.loc[:, 'visit_year'] = pd.to_datetime(df.visit_start_date).dt.year
    df.loc[:, 'diagnosis_year'] = pd.to_datetime(df.datetime_dx).dt.year

    # Clean up race variable 
    df['race_clean'] = df.race.str.lower().map(utils.RACE_DICT)

    # Create two cleaned H pylori variables
    df.loc[:, 'hpylori_active'] = df.apply(utils.clean_hpylori, axis=1) # Only stool and breath testing
    df.loc[:, 'hpylori_active_chronic'] = df.apply(utils.clean_hpylori_serology, axis=1) # Incorporate Hpylori serology and PMHx

    # Create a comprehensive tobacco and alcohol variable by merging data obtained from PMHx and social history.
    df.loc[:, 'tobacco_all'] = df[['tobacco', 'social_smoking_ever']].max(axis=1)
    df.loc[:, 'alcohol_all'] = df[['alcohol', 'social_alcohol']].max(axis=1)

    # Create a change variable for all laboratory data
    for lab in utils.LAB_VARS: 
        df.loc[:, f'{lab}_change'] = df[f'{lab}_baseline'] - df[f'{lab}_prior']

    # Categorize medication use date
    df.loc[:, 'PPI'] = df['PPI_start_date'].notna().astype(int)
    df.loc[:, 'ASA'] = df['ASA_start_date'].notna().astype(int)
    df.loc[:, 'NSAID'] = df['NSAID_start_date'].notna().astype(int)

    # Create column for all UGI cancers together (stomach and esophagus)
    df.loc[:, 'ugica'] = df[['ugica_stomach', 'ugica_esophagus']].max(axis=1)
    df.loc[df.ugica.isna(), 'ugica'] = 0

    return df 

def create_demtable(df, colname_filename, demtable_filename, demtablegrouped_filename):

    # Read in the filename with the renamed column names
    with open(colname_filename, 'r') as json_file:
        colname_dict = json.load(json_file)
        
    # Create demographic tables
    mytable = TableOne(df, columns=utils.DEM_TABLE_COLS, categorical=utils.CATEGORICAL_VARS, rename=colname_dict) #, continuous=continuous, groupby=groupby, nonnormal=nonnormal, rename=rename, pval=False)
    mytable_groupby = TableOne(df, columns=utils.DEM_TABLE_COLS, categorical=utils.CATEGORICAL_VARS, rename=colname_dict, groupby='ugica') #, continuous=continuous, groupby=groupby, nonnormal=nonnormal, rename=rename, pval=False)

    # Save demographic tables
    mytable.to_csv(demtable_filename)
    mytable_groupby.to_csv(demtablegrouped_filename)

def main(): 

    # Set up command-line argument parsing 
    parser = argparse.ArgumentParser(description="Apply exclusion criteria to data file and merge to UGI registry data.")

    # Add arguments
    parser.add_argument('cohort_file', type=str, help='The complete cohort data file to apply exclusion criteria to.')
    parser.add_argument('ugi_file', type=str, help='The UGI registry data file.')

    # Parse the arguments
    args = parser.parse_args()

    # Define directory path variable
    data_dir = Path('./../data/')
    notebook_dir = Path('./../notebook')
    results_dir = Path('./../results/')

    # Define data filenames
    data_txt_file = 'all_data_files.txt'  # Text file with list of extracted batched data in .csv.gz files
    ugi_file = args.ugi_file # ie. 'ugicancer_registry_clean.csv'

    # Define renamed column name mapping 
    colname_filename = Path('./colname_mappings.json')

    # Filenames to be saved as 
    today_date = datetime.now().strftime('%Y%m%d') # Get today's date
    final_data_file = f'cleaned_cohort_{today_date}.csv'
    final_demtable_file = f'demtable_{today_date}.csv'
    final_demtablegrouped_file = f'demtable_grouped_{today_date}.csv'

    # Apply inclusion criteria 
    df_original = apply_exclusion_critera(data_dir, data_txt_file)

    # Read UGI cancer registry data 
    df_ugi = pd.read_csv(data_dir / ugi_file, low_memory=False) #, index_col = False)

    # Select the first UGI cancer diagnosis for patients with multiple UGI cancers 
    df_ugi.sort_values(by='datetime_dx', inplace=True) # Sort duplicates by diagnosis date in ascending order 
    df_ugi_clean = df_ugi[~df_ugi.mrn.duplicated(keep='first')] # Keep the first row which will be the earliest diagnosis 

    # Merge UGI registry with extracted Epic data 
    df_merged = df_original.merge(df_ugi_clean, on='mrn', how='left')

    # Apply exclusion criteria and print out the exclusions 
    df_cohort = apply_exclusion_critera(df_merged.copy())

    # Clean cohort and define new variables 
    df_clean = clean_data(df_cohort.copy())

    # Save final cleaned cohort data
    df_clean.to_csv(results_dir / final_data_file)

    # Create demographic table 
    create_demtable(df_clean, colname_filename, results_dir / final_demtable_file, results_dir / final_demtablegrouped_file)

if __name__ == "__main__":
    main()