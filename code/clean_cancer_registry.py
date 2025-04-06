import pandas as pd
import numpy as np
import seaborn as sns
import matplotlib.pyplot as plt
from pathlib import Path
import utils

# Define directory path variable
directory = Path('./../data/')

# Define file name variable
filename = 'ugicancer_registry.xlsx'
export_filename = 'ugicancer_registry_clean.csv'
export_filename_unclassified = 'ugicancer_registry_notclassified.csv'

# Rename the columns
rename_cols = {
    'MEDRECNO': 'mrn',
    'Date of Diagnosis': 'date_dx',
    'Date of Contact': 'date_contact', 
    'LNAME': 'name_last', 
    'FNAME': 'name_first',
    'date of birth': 'dob', 
    'Tumor Site': 'tumor_site', # Based on ICD 03 codes
    'Histology': 'histology', # Based on ICD 03 codes
    'PRIMARY_TUMOR_SITE': 'primary_tumor_site',
    'BEHAVIOR': 'behavior'
}

def main(): 
    # Read the Excel file into a pandas dataframe
    file_path = directory / filename
    df = pd.read_excel(file_path)
    df.rename(columns=rename_cols, inplace=True)

    # Convert text columns to lowercase
    text_columns = df.select_dtypes(include=['object']).columns 
    df[text_columns] = df[text_columns].apply(lambda col: col.apply(lambda x: x.lower() if isinstance(x, str) else x))

    # Convert date columns from integers to datetime
    df['datetime_contact'] = pd.to_datetime(df['date_contact'].astype(int), format='%Y%m%d')
    df['datetime_dob'] = pd.to_datetime(df['dob'].astype(int), format='%Y%m%d')

    # Some date formats are YYYY and some are YYYYMMDD
    # Create a new column and set default date as Jan 1st if month/date not provided. We will exclude all patients with UGI diagnosis within 
    df['datetime_dx'] = df['date_dx'].apply(utils.convert_date_dx)
    # Create a column to indicate when we set default date.  
    df['datetime_dx_real'] = np.where(df['date_dx'] > 300000, 1, 0)

    # Classify stomach site into cardia vs noncardia 
    df['primary_tumor_site_2'] = df.apply(utils.get_tumorsite_stomach, axis=1)
    # Look at histology ICD codes to get subtype (EAC, ESCC, CGC and NCGC)
    df['subtype'] = df.apply(utils.get_cancer_subtype, axis=1)

    # Check if there remain some unclassified subtypes that did not fit
    df_notclassified = df[['subtype', 'tumor_site', 'histology']]
    print(df_notclassified[df_notclassified.subtype.isin(['NCGC', 'ESCC', 'CGC', 'EAC'])].subtype.value_counts())
    print(df_notclassified[~df_notclassified.subtype.isin(['NCGC', 'ESCC', 'CGC', 'EAC'])].subtype.value_counts())

    # Export histology codes that do not fit one of the four subtypes into .csv file for further investigation if needed 
    df_notclassified = df[~df.subtype.isin(['NCGC', 'CGC', 'EAC', 'ESCC'])].sort_values(by=['subtype', 'tumor_site', 'histology'])[['subtype', 'tumor_site', 'histology']].drop_duplicates()
    df_notclassified.to_csv(directory / export_filename_unclassified)
    print(f'\nExported ICD combinations that did not fit a subtype into {directory / export_filename_unclassified}')

    # One hot encoding for the subtypes
    df['ugica_ESCC'] = np.where(df.subtype == 'ESCC', 1, 0)
    df['ugica_EAC'] = np.where(df.subtype == 'EAC', 1, 0)
    df['ugica_CGC'] = np.where(df.subtype == 'CGC', 1, 0)
    df['ugica_NCGC'] = np.where(df.subtype == 'NCGC', 1, 0)
    df['ugica_other'] = np.where(~df.subtype.isin(['NCGC', 'CGC', 'EAC', 'ESCC']), 1, 0)

    # Export the data
    columns_of_interest = ['mrn',
       'datetime_contact', 'datetime_dob', 'datetime_dx', 'datetime_dx_real', 
       'primary_tumor_site', 'primary_tumor_site_2', 'histology', 'subtype', 
       'ugica_ESCC', 'ugica_EAC', 'ugica_CGC', 'ugica_NCGC', 'ugica_other']
    final_df = df[columns_of_interest]
    print(f'\nDate range of UGI diagnoses: {final_df.datetime_dx.min()} - {final_df.datetime_dx.max()}')

    final_df.to_csv(directory / export_filename, index=False) # Do not include the row indices as a separate column.
    print(f'Cleaned UGI registry data saved as: {directory / export_filename}')

if __name__ == "__main__":
    main()