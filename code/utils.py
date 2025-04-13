import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns 
import numpy as np

# Function to get simple description based on tumorsite_icd_description
def get_tumorsite_stomach(row):
    if row.primary_tumor_site == 'stomach': 
        if row.tumor_site == 'c160':
            return 'stomach, cardia'
        elif row.tumor_site in ['c161', 'c162', 'c163', 'c164', 'c165', 'c166']:
            return 'stomach, noncardia'
        else:
            return 'stomach, unspecified'
    else:
        return row.primary_tumor_site
        
def get_cancer_subtype(df_row):
    site = df_row.primary_tumor_site_2
    icd_code = df_row.histology

    # Convert the ICD-O-3 code to an integer
    try:
        icd_code = int(icd_code)
    except ValueError:
        return "Invalid ICD-O-3 code"

    # First, check the site and apply the corresponding subtype checks
    if site == 'esophagus':
        # Check for EAC (Esophageal Adenocarcinoma)
        if icd_code in range(8140, 8148) or icd_code in [8190, 8201, 8210, 8211, 8213, 8214, 8220, 8221, 8255, 8257] or icd_code in range(8260, 8266) or icd_code in [8310, 8323] or icd_code in range(8450, 8491) or icd_code == 8576:
            return "EAC"
        # Check for ESCC (Esophageal Squamous Cell Carcinoma)
        elif icd_code in range(8051, 8087):
            return "ESCC"
        else: return site

    elif site == 'stomach, cardia':
        # Check for CGC (Cardia Cancer)
        if icd_code == 8050 or icd_code in range(8140, 8148) or icd_code in [8190, 8201, 8210, 8211, 8213, 8214, 8220, 8221, 8255, 8257] or icd_code in range(8260, 8266) or icd_code in [8310, 8323] or icd_code in range(8450, 8491) or icd_code == 8576:
            return "CGC"
        else: 
            return site
        

    elif site == 'stomach, noncardia':
        # Check for NCGC (Non-Cardia Gastric Cancer)
        if icd_code in range(8050, 8087) or icd_code in range(8140, 8148) or icd_code in [8190, 8201, 8210, 8211, 8213, 8214, 8220, 8221, 8255, 8257] or icd_code in range(8260, 8266) or icd_code in [8310, 8323] or icd_code in range(8450, 8491) or icd_code == 8576:
            return "NCGC"
        else: 
            return site
        

    # Default case for when site is 'small intestine' or other cases
    else:
        # You can add any specific checks here for "small intestine" or other site types if needed.
        return site
    
def calculate_bmi(height, weight):
    """Takes a height and weight series and returns the BMI as a series."""
    # Convert height from inches to meters and weight from ounces to kg
    inches_to_meters = 0.0254
    ounces_to_kg = 0.0283495

    height_baseline_m = height * inches_to_meters
    weight_baseline_kg = weight * ounces_to_kg
    BMI_baseline_all = weight_baseline_kg / height_baseline_m**2
    
    return BMI_baseline_all

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
    bucket_counts = bucket_column.value_counts().reset_index().sort_values(by='count').reset_index(drop=True)
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

#Columns to include from initial data extraction               
COLNAMES_COHORT = [
    'pt_id',
    'mrn',
    # 'visit_id',
    # 'visit_id_epic',
    'sex',
    'age',
    'dob',
    'date_of_death',
    'race',
    'ethnicity',
    'preferred_language',
    'social_language',
    'social_race',
    'social_ethnicity',
    'social_alcohol',
    'social_alcohol_binge_freq',
    'social_alcohol_drink_freq',
    'social_alcohol_drinks_day',
    'social_smoking_ever',
    'social_smoking_quit',
    'social_smoking_ppd',
    'social_smoking_start_date',
    'social_smoking_quit_date',
    'social_smoking_narrative',
    # 'social_smoking_narrative_date',
    # 'xtn_epic_encounter_number',
    # 'etl_epic_encounter_key',
    'encounter_type',
    'care_site',
    'visit_start_date',
    # 'visit_end_date',
    # 'visit_start_date_minus_6mo',
    # 'visit_start_date_minus_9mo',
    # 'visit_start_date_minus_12mo',
    # 'visit_start_date_minus_18mo',
    'height_baseline',
    'weight_baseline',
    'BMI_baseline',
    'BMI_baseline_val',
    # 'BMI_baseline_date',
    # 'BMI_prior',
    # 'BMI_prior_val',
    # 'BMI_prior_date',
    'hgball_baseline',
    'hgball_baseline_val',
    'hgball_baseline_date',
    # 'hgball_prior',
    # 'hgball_prior_val',
    # 'hgball_prior_date',
    'hgb_baseline',
    'hgb_baseline_val',
    'hgb_baseline_date',
    # 'hgb_prior',
    # 'hgb_prior_val',
    # 'hgb_prior_date',
    'mcv_baseline',
    'mcv_baseline_val',
    'mcv_baseline_date',
    # 'mcv_prior',
    # 'mcv_prior_val',
    # 'mcv_prior_date',
    'wbc_baseline',
    'wbc_baseline_val',
    'wbc_baseline_date',
    # 'wbc_prior',
    # 'wbc_prior_val',
    # 'wbc_prior_date',
    'plt_baseline',
    'plt_baseline_val',
    'plt_baseline_date',
    # 'plt_prior',
    # 'plt_prior_val',
    # 'plt_prior_date',
    'sodium_baseline',
    'sodium_baseline_val',
    'sodium_baseline_date',
    # 'sodium_prior',
    # 'sodium_prior_val',
    # 'sodium_prior_date',
    'potassium_baseline',
    'potassium_baseline_val',
    'potassium_baseline_date',
    # 'potassium_prior',
    # 'potassium_prior_val',
    # 'potassium_prior_date',
    'chloride_baseline',
    'chloride_baseline_val',
    'chloride_baseline_date',
    # 'chloride_prior',
    # 'chloride_prior_val',
    # 'chloride_prior_date',
    'bicarbonate_baseline',
    'bicarbonate_baseline_val',
    'bicarbonate_baseline_date',
    # 'bicarbonate_prior',
    # 'bicarbonate_prior_val',
    # 'bicarbonate_prior_date',
    'bun_baseline',
    'bun_baseline_val',
    'bun_baseline_date',
    # 'bun_prior',
    # 'bun_prior_val',
    # 'bun_prior_date',
    'scr_baseline',
    'scr_baseline_val',
    'scr_baseline_date',
    # 'scr_prior',
    # 'scr_prior_val',
    # 'scr_prior_date',
    'magnesium_baseline',
    'magnesium_baseline_val',
    'magnesium_baseline_date',
    # 'magnesium_prior',
    # 'magnesium_prior_val',
    # 'magnesium_prior_date',
    'calcium_baseline',
    'calcium_baseline_val',
    'calcium_baseline_date',
    # 'calcium_prior',
    # 'calcium_prior_val',
    # 'calcium_prior_date',
    'phosphate_baseline',
    'phosphate_baseline_val',
    'phosphate_baseline_date',
    # 'phosphate_prior',
    # 'phosphate_prior_val',
    # 'phosphate_prior_date',
    'ast_baseline',
    'ast_baseline_val',
    'ast_baseline_date',
    # 'ast_prior',
    # 'ast_prior_val',
    # 'ast_prior_date',
    'alt_baseline',
    'alt_baseline_val',
    'alt_baseline_date',
    # 'alt_prior',
    # 'alt_prior_val',
    # 'alt_prior_date',
    'alp_baseline',
    'alp_baseline_val',
    'alp_baseline_date',
    # 'alp_prior',
    # 'alp_prior_val',
    # 'alp_prior_date',
    'tbili_baseline',
    'tbili_baseline_val',
    'tbili_baseline_date',
    # 'tbili_prior',
    # 'tbili_prior_val',
    # 'tbili_prior_date',
    'tprotein_baseline',
    'tprotein_baseline_val',
    'tprotein_baseline_date',
    # 'tprotein_prior',
    # 'tprotein_prior_val',
    # 'tprotein_prior_date',
    'albumin_baseline',
    'albumin_baseline_val',
    'albumin_baseline_date',
    # 'albumin_prior',
    # 'albumin_prior_val',
    # 'albumin_prior_date',
    'tsh_baseline',
    'tsh_baseline_val',
    'tsh_baseline_date',
    # 'tsh_prior',
    # 'tsh_prior_val',
    # 'tsh_prior_date',
    'vitD_baseline',
    'vitD_baseline_val',
    'vitD_baseline_date',
    # 'vitD_prior',
    # 'vitD_prior_val',
    # 'vitD_prior_date',
    'triglycerides_baseline',
    'triglycerides_baseline_val',
    'triglycerides_baseline_date',
    # 'triglycerides_prior',
    # 'triglycerides_prior_val',
    # 'triglycerides_prior_date',
    'LDL_baseline',
    'LDL_baseline_val',
    'LDL_baseline_date',
    # 'LDL_prior',
    # 'LDL_prior_val',
    # 'LDL_prior_date',
    'hgba1c_baseline',
    'hgba1c_baseline_val',
    'hgba1c_baseline_date',
    # 'hgba1c_prior',
    # 'hgba1c_prior_val',
    # 'hgba1c_prior_date',
    'hpylori_earliest_date',
    'hpylori_earliest_value',
    'hpylori_earliest_range_high',
    'hpylori_earliest_range_low',
    'hpylori_earliest_result_num',
    'hpylori_earliest_test',
    'hpylori_stool_date',
    'hpylori_stool_value',
    'hpylori_stool_range_high',
    'hpylori_stool_range_low',
    'hpylori_iga_date',
    'hpylori_iga_value',
    'hpylori_iga_range_high',
    'hpylori_iga_range_low',
    'hpylori_igm_date',
    'hpylori_igm_value',
    'hpylori_igm_range_high',
    'hpylori_igm_range_low',
    'hpylori_igg_date',
    'hpylori_igg_value',
    'hpylori_igg_range_high',
    'hpylori_igg_range_low',
    'hpylori_breath_date',
    'hpylori_breath_value',
    'hpylori_breath_range_high',
    'hpylori_breath_range_low',
    'gastricca_start_date',
    'gastricca',
    'esophagealca_start_date',
    'esophagealca',
    'hnca_start_date',
    'hnca',
    'achalasia_start_date',
    'achalasia',
    'pud_start_date',
    'pud',
    'gerd_start_date',
    'gerd',
    'hpylori_start_date',
    'hpylori',
    'barretts_start_date',
    'barretts',
    'cad_start_date',
    'cad',
    'tobacco_start_date',
    'tobacco',
    'alcohol_start_date',
    'alcohol',
    'famhx_cancer',
    'famhx_esophagealca',
    'famhx_gastricca',
    'famhx_colonca',
    'famhx_barretts',
    'ASA_start_date',
    'NSAID_start_date',
    'PPI_start_date',
    'ASA_use',
    'NSAID_use',
    'PPI_use'
]

RACE_DICT = {
    'no matching concept': "No matching concept",
    'prefer not to say': "No matching concept",
    'mixed racial group': "Other",
    'white': "White",
    'american indian or alaska native': "Other",
    'african american': "Black or African American",
    'madagascar': "Black or African American",
    'african': "Black or African American",
    'west indian': "Other",
    'trinidadian': "Other",
    'dominica islander': "Other",
    'jamaican': "Other",
    'haitian': "Other",
    'barbadian': "Other",
    'native hawaiian or other pacific islander': "Other",
    'other pacific islander': "Other",
    'okinawan': "Other",
    'melanesian': "Other",
    'maldivian': "Other",
    'micronesian': "Other",
    'polynesian': "Other",
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
    "ugica",
    "death",
    "subtype", 

    "visit_year", 
    "diagnosis_year",
    "encounter_type",

    "sex", 
    "sex_missing",
    "race_clean", 
    "race_clean_missing",
    "ethnicity", 
    "ethnicity_missing",
    "social_language", 
    
    "alcohol_all",
    "alcohol_all_missing",
    "alcohol_binary",
    "alcohol_binary_missing",
    "tobacco_all",
    "tobacco_all_missing",
    "tobacco_binary",
    "tobacco_binary_missing",
    "hpylori_active", 
    "hpylori_active_chronic", 
    'hpylori_active_chronic_missing',
    'hpylori_active_chronic_binary',
    "hnca", 
    "achalasia", 
    "pud", 
    "gerd", 
    "cad", 
    "barretts",
    "famhx_cancer", 
    "famhx_esophagealca", 
    "famhx_gastricca", 
    "famhx_colonca", 
    "famhx_barretts", 
    "ASA", 
    "PPI", 
    "NSAID"
]
 
NUMERICAL_VARS = [
    "age", 
    "days_to_event",
    "months_to_event",
    "days_to_dx",
    "days_to_death",

    'height_baseline',
    'weight_baseline',
    'BMI_baseline_all',
    'BMI_baseline', 

    'hgball_baseline', 
    'hgball_baseline_imputed_mean',

    'hgb_baseline', 
    'mcv_baseline', 
    'wbc_baseline', 
    'plt_baseline', 
    'sodium_baseline', 
    'potassium_baseline', 
    'chloride_baseline', 
    'bicarbonate_baseline', 
    'bun_baseline', 
    'scr_baseline', 
    'magnesium_baseline', 
    'calcium_baseline', 
    'phosphate_baseline', 
    'ast_baseline', 
    'alt_baseline', 
    'alp_baseline', 
    'tbili_baseline', 
    'tprotein_baseline', 
    'albumin_baseline', 
    'tsh_baseline', 
    'vitD_baseline', 
    'triglycerides_baseline', 
    'LDL_baseline', 
    'hgba1c_baseline'
]

VARS_TO_ANALYZE = CATEGORICAL_VARS + NUMERICAL_VARS