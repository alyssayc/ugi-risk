import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns 
import numpy as np

def convert_date_dx(date):
    """
    Convert an float date to datetime depending on the integer format. 
    If year only, will default specify Jan 01 [year]
    If year month only, will default specify [month] 01 [year]
    if year month and day specified, will convert to datetime representation
    
    Parameters:
    - date: array of floats specifying the date
    
    Returns:
    array of datetime with year, month and date 
    
    Example: 
        >>> convert_date_dx(df['date_dx']))
    """
    if date < 3000:
        return pd.to_datetime(date, format='%Y')
    elif 3000 <= date < 300000: 
        return pd.to_datetime(date, format='%Y%m')
    else:
        return pd.to_datetime(date, format='%Y%m%d')
    
def generate_bucket_barplot(column, bins, labels):
    """
    Generate a bucket table and plot a barplot showing the distribution of values in buckets.

    Parameters:
    - column: pandas Series or array-like, the input column containing the values to be categorized into buckets.
    - bins: array of ints specifying the bin cutoffs.
    - labels: array of strings specifying the bin labels. 
    
    Returns:
    None

    Example:
        >>> generate_bucket_barplot(df['date_dx'], [1000, 3000, 30000000], ['yyyy', 'yyyymmdd'])
    """
        
    # Use pd.cut to categorize values into buckets
    bucket_column = pd.cut(column, bins=bins, labels=labels)

    # Count the number of values in each bucket
    bucket_counts = bucket_column.value_counts().reset_index().sort_values(by='index').reset_index(drop=True)
    bucket_counts.columns = ['bucket', 'count']
    
    # Print the bucket table
    print("Bucket Table:")
    print(bucket_counts)

    # Plot the barplot
    sns.barplot(x='bucket', y='count', data=bucket_counts)
    plt.xlabel('Value Range')
    plt.ylabel('Count')
    plt.title('Distribution of Values in Buckets')

    # Add count labels on the bars
    for index, row in bucket_counts.iterrows():
        plt.text(index, row['count'], f"{row['count']}", color='black', ha="center")

    plt.show()


def calculate_diff_in_months(date1, date2):
    if pd.isna(date1) or pd.isna(date2):
        return pd.NA 
    
    elif isinstance(date1, str) or isinstance(date2, str):
        print(date1, date2)
        
    average_days_per_month = 30.44
    return round((date2-date1).days/average_days_per_month)

def clean_hpylori(row):
    test = row['hpylori_earliest_test']
    value = str(row['hpylori_earliest_value']).strip().lower() 
    
    # Check if the test type is missing
    if pd.isna(test):
        return np.nan
    
    # Define logic based on test type
    if test in ['stool', 'breath']:
        if value == 'negative': 
            return 0
        elif value == 'positive':
            return 1
    
    return np.nan


def clean_hpylori_serology(row):
    hpylori_active = float(row['hpylori_active'])
    test = row['hpylori_earliest_test']
    value = str(row['hpylori_earliest_value']).strip().lower() 
    igg_high_range = row['hpylori_igg_range_high']
    pmhx_hpylori = float(row['hpylori'])
    
    # Check if both arrays are all NaN
    if np.all(np.isnan(hpylori_active)) and np.all(np.isnan(pmhx_hpylori)):
        result = np.nan  # Or handle as needed
    else:
        result = np.nanmax([hpylori_active, pmhx_hpylori])
    
    if test in ['IgA', 'IgM']:
        if value == '<9.0':
            result = np.nanmax([0, result])
    
    elif test == 'IgG':
        if pd.notna(igg_high_range):
            try:
                value_float = float(value)
                if value_float > igg_high_range:
                    result = np.nanmax([1, result])
                else:
                    result = np.nanmax([0, result])
            except ValueError:
                pass
    
    return result

RACE_DICT = {
    'no matching concept': "Not Available",
    'prefer not to say': "Prefer not to say",
    'mixed racial group': "Mixed",
    'white': "White",
    'american indian or alaska native': "American Indian or Alaska Native",
    'african american': "Black or African American",
    'madagascar': "Black or African American",
    'african': "Black or African American",
    'west indian': "West Indian",
    'trinidadian': "West Indian",
    'dominica islander': "West Indian",
    'jamaican': "West Indian",
    'haitian': "West Indian",
    'barbadian': "West Indian",
    'native hawaiian or other pacific islander': "Native Hawaiian or Other Pacific Islander",
    'other pacific islander': "Native Hawaiian or Other Pacific Islander",
    'okinawan': "Native Hawaiian or Other Pacific Islander",
    'melanesian': "Native Hawaiian or Other Pacific Islander",
    'maldivian': "Native Hawaiian or Other Pacific Islander",
    'micronesian': "Native Hawaiian or Other Pacific Islander",
    'polynesian': "Native Hawaiian or Other Pacific Islander",
    'asian': "Asian",
    'bangladeshi': "Asian",
    'laotian': "Asian",
    'asian indian': "Asian",
    'burmese': "Asian",
    'chinese': "Asian",
    'korean': "Asian",
    'japanese': "Asian",
    'taiwanese': "Asian",
    'vietnamese': "Asian",
    'indonesian': "Asian",
    'cambodian': "Asian",
    'filipino': "Asian",
    'malaysian': "Asian",
    'sri lankan': "Asian",
    'pakistani': "Asian",
    'nepalese': "Asian",
    'thai': "Asian",
    'singaporean': "Asian",
    'bhutanese': "Asian",
    'hmong': "Asian"
}

CATEGORICAL_VARS = [
    "primary_tumor_site", 
    "sex", 
    "race_clean", 
    "ethnicity", 
    "social_language", 
    "visit_year", 
    "diagnosis_year",
    "alcohol_all",
    "alcohol", 
    "social_alcohol", 
    "social_alcohol_binge_freq", 
    "social_alcohol_drink_freq", 
    "social_alcohol_drinks_day", 
    "tobacco_all",
    "tobacco", 
    "social_smoking_ever", 
    "social_smoking_quit", 
    "hpylori_active", 
    "hpylori_active_chronic", 
    "hnca", 
    "achalasia", 
    "pud", 
    "gerd", 
    "cad", 
    "famhx_cancer", 
    "famhx_esophagealca", 
    "famhx_gastricca", 
    "famhx_colonca", 
    "ASA", 
    "PPI", 
    "NSAID"
]

LAB_VARS = [
    'hgball', 
    'hgb', 
    'mcv', 
    'wbc', 
    'plt', 
    'sodium', 
    'potassium', 
    'chloride', 
    'bicarbonate', 
    'bun', 
    'scr', 
    'magnesium', 
    'calcium', 
    'phosphate', 
    'ast', 
    'alt', 
    'alp', 
    'tbili', 
    'tprotein', 
    'albumin', 
    'tsh', 
    'vitD', 
    'triglycerides', 
    'LDL', 
    'hgba1c'
]

NUMERICAL_VARS = ['BMI'] + LAB_VARS
PRIOR_VARS = [f'{var}_prior' for var in NUMERICAL_VARS]
BASELINE_VARS = [f'{var}_baseline' for var in NUMERICAL_VARS]
NUMERICAL_ALL_VARS = PRIOR_VARS + BASELINE_VARS + ['social_smoking_ppd']

DEM_TABLE_COLS = CATEGORICAL_VARS + BASELINE_VARS
VARS_TO_ANALYZE = ['ugica'] + CATEGORICAL_VARS + NUMERICAL_ALL_VARS
                 
COLNAMES_DATES = [
    'visit_start_date',
    'visit_end_date',
    'BMI_baseline_date',
    'BMI_prior_date',
    'hgball_baseline_date',
    'hgball_prior_date',
    'hgb_baseline_date',
    'hgb_prior_date',
    'mcv_baseline_date',
    'mcv_prior_date',
    'wbc_baseline_date',
    'wbc_prior_date',
    'plt_baseline_date',
    'plt_prior_date',
    'sodium_baseline_date',
    'sodium_prior_date',
    'potassium_baseline_date',
    'potassium_prior_date',
    'chloride_baseline_date',
    'chloride_prior_date',
    'bicarbonate_baseline_date',
    'bicarbonate_prior_date',
    'bun_baseline_date',
    'bun_prior_date',
    'scr_baseline_date',
    'scr_prior_date',
    'magnesium_baseline_date',
    'magnesium_prior_date',
    'calcium_baseline_date',
    'calcium_prior_date',
    'phosphate_baseline_date',
    'phosphate_prior_date',
    'ast_baseline_date',
    'ast_prior_date',
    'alt_baseline_date',
    'alt_prior_date',
    'alp_baseline_date',
    'alp_prior_date',
    'tbili_baseline_date',
    'tbili_prior_date',
    'tprotein_baseline_date',
    'tprotein_prior_date',
    'albumin_baseline_date',
    'albumin_prior_date',
    'tsh_baseline_date',
    'tsh_prior_date',
    'vitD_baseline_date',
    'vitD_prior_date',
    'triglycerides_baseline_date',
    'triglycerides_prior_date',
    'LDL_baseline_date',
    'LDL_prior_date',
    'hgba1c_baseline_date',
    'hgba1c_prior_date',
    'hpylori_earliest_date',
    'hpylori_stool_date',
    'hpylori_iga_date',
    'hpylori_igm_date',
    'hpylori_igg_date',
    'hpylori_breath_date',
    'gastricca_start_date',
    'esophagealca_start_date',
    'hnca_start_date',
    'achalasia_start_date',
    'pud_start_date',
    'gerd_start_date',
    'hpylori_start_date',
    'cad_start_date',
    'tobacco_start_date',
    'alcohol_start_date',
    'ASA_start_date',
    'NSAID_start_date',
    'PPI_start_date',
    'datetime_contact',
    'datetime_dob',
    'datetime_dx',
    'datetime_dx_real'
]                 


