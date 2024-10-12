import pandas as pd
import numpy as np
import seaborn as sns
import matplotlib.pyplot as plt
from pathlib import Path
from tableone import TableOne, load_dataset
import dask.dataframe as dd
import json
import os
import gzip
from datetime import datetime
import argparse

# Set up command-line argument parsing
parser = argparse.ArgumentParser(description='Apply inclusion and exclusion criteria to a cohort.')
parser.add_argument('--second_enc_lower_bound', type=str, required=True, help='Minimum number of months after which a second encounter can occur.')
parser.add_argument('--second_enc_upper_bound', type=str, required=True, help='Maximum number of months after which a second encounter can occur. If infinity, "inf"')

args = parser.parse_args()

second_enc_lower_bound = float(args.second_enc_lower_bound)

if args.second_enc_upper_bound == 'inf':
    second_enc_upper_bound = args.second_enc_upper_bound
else: 
    second_enc_upper_bound = float(args.second_enc_upper_bound)

# Directory and files for existing data 
data_dir = Path('./') 
input_txt_file = 'all_data_files.txt'  # Text file with list of .csv.gz files
ugicancer_file = 'ugicancer_registry_clean.csv'  # File to merge with

# Filenames to be saved as 
today_date = datetime.now().strftime('%Y%m%d') # Get today's date
cohort_filename = f'final_cohort_{today_date}.csv'
consort_diagram_filename = f'consort_diagram_{today_date}.csv'

# Read the ugicancer_registry_clean.csv file
df_ugica = pd.read_csv(data_dir / ugicancer_file)
print(data_dir/ugicancer_file)
df_ugi_mrns = set(df_ugica.mrn.unique()) # Set of all MRNS for our cases 

date_variables = ['visit_start_date', 'visit_start_date_minus_18mo', 'visit_start_date_minus_6mo', 'gastricca_start_date', 'esophagealca_start_date']
cohort_mrns = set()
cohort = [] # List to accumulate rows for the cohort DataFrame 
cohort_cols = [] # Set after reading in the first chunk
futureencs = {} # Dict to store visit start dates for each MRN 
consort_diagram_csv = [] # Store size information to create consort diagram later
consort_diagram_cols = ['filename', 'pre shape', 'post shape', 'pre MRNs', 'post MRNs', 'incl - has a future enc in 6-18mo', 'excl - age not 40-85', 'excl - gastric ca', 'excl - eso ca', 'excl - first enc']
incl_encounters = set()
excl_age_cutoff = (40, 85)
excl_age = set()
excl_gastricca = set()
excl_esophagealca = set()

with open(data_dir / input_txt_file, 'r') as file:
    file_list = [line.strip() for line in file if line.strip()]

    for filename in file_list:
        df_chunk = pd.read_csv(data_dir / filename)
        print(f'{filename}: {df_chunk.shape}')

        # Set the column names for the cohort
        if len(cohort_cols) == 0:
            cohort_cols = df_chunk.columns  

        # Sort from latest date to earliest because the algorithm before will check to see if there is a future encounter in 6-18 months 
        df_chunk.sort_values(by='visit_start_date', ascending=False, inplace=True) 

        # Convert to datetime objects
        for date_col in date_variables:
            # Print the number of nulls before and after converting to see if there are errors with conversion.
            # coercing errors forces values that are not datetime into null.
            print(f'Number of nulls before converting: {df_chunk[date_col].isna().sum()}')
            df_chunk[date_col] = pd.to_datetime(df_chunk[date_col], errors='coerce') 
            print(f'Number of nulls after converting: {df_chunk[date_col].isna().sum()}')

        for idx, row in df_chunk.iterrows():
            excluded = False # Flag if meets exclusion criteria 
            included = False # Flag if meets inclusion criteria 
            mrn = row.mrn
            age = row.age
            visit_start_date = row.visit_start_date

            # Inclusion criteria - select the first encounter for each mrn 
            if mrn in incl_encounters:
                pass # Already included
            # Inclusion criteria - Has another future encounter in [lower bound, upper bound]
            # multiple encounters for this mrn already 
            elif mrn in futureencs:
                if second_enc_upper_bound == 'inf':
                    incl_encounters.add(mrn)
                    included = True
                # ex. is there another encounter in 6-18 mo
                elif isinstance(second_enc_upper_bound, float):
                    visit_start_date_plus_lower_bound = visit_start_date + pd.DateOffset(months=second_enc_lower_bound)
                    visit_start_date_plus_upper_bound = visit_start_date + pd.DateOffset(months=second_enc_upper_bound)

                    if any(visit_start_date_plus_lower_bound <= future_date <= visit_start_date_plus_upper_bound for future_date in futureencs[mrn]):
                        incl_encounters.add(mrn)
                        included = True
                else:
                    futureencs[mrn].append(visit_start_date)
            # first encounter for this mrn 
            else:
                futureencs[mrn] = [visit_start_date]

            # Only evaluate for exclusion critera in those that have met inclusion criteria. 
            if included:                
                # Exclusion criterias 
                if age < excl_age_cutoff[0] and age > excl_age_cutoff[1]: 
                    excl_age.add(mrn) # Count how many people are excluded by this criteria 
                    excluded = True

                # Exclusion criteria - gastric cancer 
                if row.gastricca == 1:
                    # if dx date exists, only exclude pts whose gastric ca diagnosis date is before the visit date 
                    if row.gastricca_start_date < visit_start_date: 
                        excl_gastricca.add(mrn)
                        excluded = True
             
                # Exclusion criteria - esophageal cancer 
                if row.esophagealca == 1:
                    if row.esophagealca_start_date < visit_start_date: 
                        excl_esophagealca.add(mrn)
                        excluded = True

            # Apply criteria 
            if included: # and not excluded:                 
                cohort.append(row)
                cohort_mrns.add(mrn)
        
        consort_diagram_csv.append([filename, df_chunk.shape[0], len(cohort), df_chunk.mrn.nunique(), len(cohort_mrns), len(incl_encounters), len(excl_age), len(excl_gastricca), len(excl_esophagealca), None])
        print(f'Size of cohort mrns: {len(cohort_mrns)}')

# Turn into a dataframe 
df_cohort = pd.DataFrame(cohort, columns=cohort_cols)

# # Inclusion criteria - select the first encounter for each mrn 
# df_cohort_firstenc = df_cohort.sort_values(by='visit_start_date').drop_duplicates(subset='mrn', keep='first')

# Merge with UGI dataframe 
df_cohort_final = pd.merge(df_cohort, df_ugica, how='left')

# Finish collecting counts for consort diagram 
consort_diagram_csv.append(['df_cohort_firstenc', df_cohort.shape[0], df_cohort_firstenc.shape[0], df_cohort.mrn.nunique(), df_cohort_firstenc.mrn.nunique(), None, None, None, None, df_cohort.mrn.nunique() - df_cohort_firstenc.mrn.nunique()])
consort_diagram_csv.append(['df_cohort_final', None, df_cohort_final.shape[0], len(futureencs), df_cohort_final.mrn.nunique(), None, None, None, None, None])
df_consort_diagram = pd.DataFrame(consort_diagram_csv, columns=consort_diagram_cols)

# Save to CSV
df_cohort_final.to_csv(data_dir / cohort_filename)
df_consort_diagram.to_csv(data_dir / consort_diagram_filename)

# Debugging the discrepancy with MRN numbers after importing 
# Save the list of MRNs to a json file 
with open('final_unique_mrns.json', 'w') as json_file:
    json.dump(df_cohort_final.mrn.tolist(), json_file)