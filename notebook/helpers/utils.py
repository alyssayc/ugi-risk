import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from sklearn.metrics import confusion_matrix
from scipy.stats import percentileofscore
from pathlib import Path
import json
import os

event_pretty_label = {
    "ugica_5yr": "UGI cancer", 
    "escc_5yr": "Esophageal SCC",
    "eac_5yr": "Esophageal AC",
    "cgc_5yr": "Cardia Gastric AC",
    "ncgc_5yr": "Noncardia Gastric AC"
}

def generate_risk_percentile_df(df_validation_risk, pred_risk, percentile_cutoffs, optimal_threshold):

    df_validation_risk['actual_percentile'] = df_validation_risk[pred_risk].apply(lambda x: percentileofscore(df_validation_risk[pred_risk], x, kind='weak')/100.)

    # Example inputs
    percentile_cutoffs_sorted = sorted(set(percentile_cutoffs))
    percentile_high_risk = 0.9 # Chosen percentile for high risk group, can vary to compare  

    labels = percentile_cutoffs_sorted[:-1]

    # Assign risk groups based on custom percentile cutoffs
    df_validation_risk['risk_group'] = pd.qcut(
        df_validation_risk[pred_risk],
        q=percentile_cutoffs_sorted,
        labels=labels,
        duplicates='drop'  # in case there are tied values
    )

    # One-hot encoding, create a boolean column for each percentile cutoff
    for idx, label in enumerate(labels):
        risk_col = f"risk_p{percentile_cutoffs_sorted[idx+1]}"
        include_labels = labels[:idx+1]
        df_validation_risk[risk_col] = np.where(df_validation_risk['risk_group'].isin(include_labels), 0, 1)

    # Custom low/high risk cutoff
    high_risk_idx = percentile_cutoffs_sorted.index(percentile_high_risk)
    df_validation_risk['high_risk'] = np.where(df_validation_risk['risk_group'] == labels[high_risk_idx], 1, 0)

    # Optimal Youden threshold cutoff
    df_validation_risk['high_risk_youden'] = np.where(df_validation_risk[pred_risk] >= optimal_threshold, 1, 0)
    
    return df_validation_risk

def classification_metrics(predicted_risk_df, risk_group_name, actual_event_name, strata = 'all'):
    predicted_class = predicted_risk_df[risk_group_name]
    actual_class = predicted_risk_df[actual_event_name]

    # Get confusion matrix: TN, FP, FN, TP
    cm = confusion_matrix(actual_class, predicted_class).ravel()
    
    # If no cases return
    if len(cm) != 4:
        return {}
    
    tn, fp, fn, tp = cm
    
    # Calculate metrics
    sensitivity = tp / (tp + fn) if (tp + fn) > 0 else 0
    specificity = tn / (tn + fp) if (tn + fp) > 0 else 0
    ppv = tp / (tp + fp) if (tp + fp) > 0 else 0
    npv = tn / (tn + fn) if (tn + fn) > 0 else 0
    youden_index = sensitivity + specificity - 1
    cer = fn / (fn + tn) # control event rate is the number of cases in those not screened 
    ser = tp / (tp + fp) # screened event rate is the number of cases found / those screened 
    aer = ser - cer # absolute event reduction 
    nns = 1/aer 

    total_in_risk_group = predicted_class.sum() #tp+fp
    total_cases_in_risk_group = tp
    prevalence_in_risk_group = round((total_cases_in_risk_group / total_in_risk_group) * 100, 1) 

    # Return as dictionary
    return {
        "risk_group": risk_group_name,
        "risk_percentile": float(risk_group_name[6:]) if risk_group_name[0:6] == 'risk_p' else "youden", # Get the percentile appended to the end of the risk group name unless youden
        "event": actual_event_name,
        "strata": strata,
        "actual controls": fp+tn,
        "actual cases": tp+fn,
        "total pts in risk group": total_in_risk_group,
        "cancer prevalence in risk group": f'{total_cases_in_risk_group} ({prevalence_in_risk_group}%)',
        "prevalence": prevalence_in_risk_group,
        "tp": tp,
        "fp": fp,
        "fn": fn,
        "tn": tn,
        "pred correct": (tp+tn)/(tp+fp+fn+tn),
        "pred incorrect": (fp+fn)/(tp+fp+fn+tn),
        "sensitivity": sensitivity*100,
        "specificity": specificity*100,
        "ppv": ppv*100,
        "npv": npv*100,
        "nns": nns,
        "youden_index": youden_index
    }


def save_to_json(variable, filename, key=None):
    # If the file exists, load existing data
    if os.path.exists(filename):
        with open(filename, 'r') as f:
            try:
                data = json.load(f)
            except json.JSONDecodeError:
                data = {}
    else:
        data = {}

    # Append or update data
    if key in data:
        data[key].update(variable)
    else: 
        data[key] = variable

    # Save the updated data
    with open(filename, 'w') as f:
        json.dump(data, f, indent=4)

    print(f"Saved to {filename}")

