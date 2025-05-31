library(bshazard)
library(survival)
library(tidyr)
library(dplyr)
library(magrittr)
library(tableone)
library(pROC)
library(PRROC)
library(caret)
library(survivalROC)
library(survminer)
library(scales)
library(finalfit)
library(broom)
library(broom.helpers)
library(purrr)
library(gridExtra)

outcomes <- c(
    'ugica', 'ugica_10yr', 'ugica_5yr', 'ugica_3yr', 'ugica_1yr',
    'ugica_ESCC', 'escc_10yr', 'escc_5yr', 'escc_3yr', 'escc_1yr',
    'ugica_EAC', 'eac_10yr', 'eac_5yr', 'eac_3yr', 'eac_1yr',
    'ugica_CGC', 'cgc_10yr', 'cgc_5yr', 'cgc_3yr', 'cgc_1yr',
    'ugica_NCGC', 'ncgc_10yr', 'ncgc_5yr', 'ncgc_3yr', 'ncgc_1yr'
)

# Ignore these columns
cols_to_ignore <- c(
  'months_to_event', 
  'death', 'subtype', 'visit_year', 'diagnosis_year', 'encounter_type', 'social_language', 
  'days_to_event', 'days_to_dx', 'days_to_death',
  "sex", "tobacco_all", "tobacco_all_missing", "tobacco_binary_missing", "barretts", # Duplicate variables 
  "race_clean_missing", "ethnicity_missing", "alcohol_all", "hpylori_active", "hpylori_active_chronic", 
  "hgball_baseline_imputed_mean", "BMI_baseline", "height_baseline", 'weight_baseline',
  "eac_risk_factors_screening", "meets_eac_screening", "age_bucket", "visit_year_bucket", # Vars for stratified analysis
  outcomes 
)

# Variables to do stratified analysis on 
cols_to_stratify <- c('race_clean', 'sex_missing', 'age_bucket', 'visit_year_bucket')

# For logistic regression forest plots 
univariate_forestplot_pretty_names <- c(
"PPI.PPI1" = "Ever PPI use",
"pud.pud1" = "Peptic ulcer disease",
"hnca.hnca1" = "Head and neck cancer",
"cad.cad1" = "Coronary artery disease", 
"gerd.gerd1" = "GERD",
"famhx_cancer.famhx_cancer1" = "FHx of cancer",
"famhx_gastricca.famhx_gastricca1" = "FHx of gastric cancer",
"ASA.ASA1" = "Ever aspirin use",
"sex_missing.sex_missingMALE" = "Sex - Male",
"tobacco_binary.tobacco_binary1" = "Ever tobacco use",
"NSAID.NSAID1" = "Ever NSAID use",
"age.age" = "Age",
"famhx_colonca.famhx_colonca1" = "FHx of colon cancer",
"ethnicity.ethnicityHispanic or Latino" = "Ethnicity - Hispanic or Latino",
"race_clean.race_cleanAsian" = "Race - Asian",
"race_clean.race_cleanBlack or African American" = "Race - Black or African American",
"race_clean.race_cleanOther" = "Race - Other",
"race_clean.race_cleanNA" = "Race - Unknown",
"race_clean.race_cleanNo matching concept" = "Race - No Matching Concept",
"ethnicity.ethnicityNo matching concept" = "Ethnicity - Unknown"
)

multivar_df_pretty_names <- c(
    age = "Age",
    sex_missing = "Sex", 
    race_clean = "Race", 
    ethnicity = "Ethnicity", 
    alcohol_binary = "Alcohol", 
    tobacco_binary = "Tobacco", 
    pud = "Peptic ulcer disease",
    gerd = "GERD",
    cad = "Coronary artery disease", 
    barretts = "Barretts esophagus",
    famhx_cancer = "Family history of cancer",
    famhx_gastricca = "Family history of gastric cancer", 
    famhx_colonca = "Family history of colon cancer",
    ASA = "Aspirin use",
    PPI = "Proton pump inhibitor use"
)

multivar_forestplot_pretty_names <- c(
    "ethnicityNo matching concept" = "Ethnicity - Unknown",
    "alcohol_all2.0" = "Alcohol Use - Current",
    "alcohol_all1.0" = "Alcohol Use - Prior",
    "alcohol_allNo matching concept" = "Alcohol Use - Unknown",
    "ASA1" = "Ever aspirin use",
    "tobacco_binary1" = "Ever tobacco use",
    "NSAID1" = "Ever NSAID use",
    "hgb_imputed_scaled" = "Most recent hemoglobin",
    "race_cleanOther" = "Race - Other",
    "race_cleanNA" = "Race - Unknown",
    "ethnicityHispanic or Latino" = "Ethnicity - Hispanic or Latino",
    "race_cleanBlack or African American" = "Race - Black or African American",
    "age" = "Age",
    "race_cleanAsian" = "Race - Asian",
    "race_cleanNo matching concept" = "Race - Unknown",
    "sex_missingMALE" = "Sex - Male",
    "famhx_gastricca1" = "FHx of gastric cancer",
    "hpylori_binary1.0" = "Active or chronic H.pylori infection",
    "PPI1" = "Ever PPI use",
    "barretts1" = "Barretts esophagus",
    "cad1" = "Coronary artery disease", 
    "famhx_cancer1" = "FHx of cancer",
    "famhx_colonca1" = "FHx of colon cancer",
    "gerd1" = "GERD",
    "pud1" = "Peptic ulcer disease"
)


# Partitions data into training and validation set, percentage split p 
partition_data <- function(data, selected_vars, outcome, seed = 123, p = 0.8) {
  rdf <- data %>%
    select(months_to_event, all_of(outcomes), all_of(selected_vars), all_of(cols_to_stratify)) %>%
    drop_na()
  
  set.seed(seed)
  train_index <- createDataPartition(rdf[[outcome]], p = p, list = FALSE)
  
  train_set <- rdf[train_index, ]
  validation_set <- rdf[-train_index, ]
  
  # Check the distribution of the outcome variable in each set
  print(paste(c("Dataset Controls", "Dataset Cases"), table(rdf[[outcome]])))  # Original dataset
  print(paste(c("Training Controls", "Training Cases"), table(train_set[[outcome]])))  # Training set
  print(paste(c("Validation Controls", "Validation Cases"), table(validation_set[[outcome]])))  # Validation set
  cat("\n")

  list(train_set = train_set, validation_set = validation_set)
}

# Trains logistic regression model
train_logreg_model <- function(train_set, selected_vars, outcome, model_func = glm) {
  formula_str <- paste(outcome, "~", paste(selected_vars, collapse = " + "))
  formula <- as.formula(formula_str)
  model <- model_func(formula, data = train_set, family = binomial)
  return(model)
}

# Gets the univariate analysis summary statistics and returns in a dataframe 
get_logreg_univariate_summary <- function(model, var, categorical_vars) {
    model_summary <- summary(model)

    # Get odds ratios and confidence intervals
    coef <- exp(coef(model))
    confint_vals <- exp(confint(model))  # 95% CI for log-odds, exponentiated to OR
    p_value <- coef(summary(model))[, "Pr(>|z|)"]

    # Extract full term names (e.g., "sexMale", "stageIII")
    terms <- rownames(coef(summary(model)))

    # Extract factor levels (remove variable name prefix)
    is_factor <- var %in% categorical_vars
    levels_clean <- if (is_factor) {
        sub(paste0("^", var), "", terms)
    } else {
        terms  # use full term name for numeric variables
    }

    model_df <- data.frame(
        Variable = var,
        Level = levels_clean,
        OR = coef[terms],
        CI_lower = confint_vals[terms, 1],
        CI_upper = confint_vals[terms, 2],
        p_value = p_value[terms]
    )

    return(model_df)

}

plot_univariate_forest <- function(forestplot_df) {
    # Define color and label formatting
    forestplot_df <- forestplot_df %>%
    mutate(
        Variable_pretty = univariate_forestplot_pretty_names[Variable_full],
        Variable_pretty = ifelse(is.na(Variable_pretty), Variable_full, Variable_pretty),
        sig = case_when(
        p_value < 0.001 ~ "***",
        p_value < 0.01 ~ "**",
        p_value < 0.05 ~ "*",
        TRUE ~ ""
        ),
        or_label = sprintf("%.2f (%.2f–%.2f)", OR, CI_lower, CI_upper),
        Variable_labeled = paste0(Variable_pretty, " ", sig),  # add asterisks here
        color_group = ifelse(OR >= 1, "OR > 1", "OR < 1")
    ) %>%
    arrange(OR) %>%
    mutate(Variable_labeled = factor(Variable_labeled, levels = unique(Variable_labeled)))

    # Plot
    ggplot(forestplot_df, aes(x = OR, y = Variable_labeled)) +
    geom_point(aes(color = color_group), size = 3) +
    geom_errorbarh(aes(xmin = CI_lower, xmax = CI_upper), height = 0.25) +
    geom_text(aes(x = CI_upper * 1.05, label = or_label), hjust = -0.1, size = 4) +  # Shows OR + CI
    geom_vline(xintercept = 1, linetype = "dashed", color = "gray50") +
    coord_cartesian(clip = "off") + 
    scale_color_manual(
        values = c("OR > 1" = "lightblue", "OR < 1" = "hotpink"),
        guide = "none"
    ) +
    scale_x_continuous(
        trans = "log10",
        breaks = c(0.5, 1, 2, 4),
        labels = c("0.5", "1", "2", "4"),
        expand = expansion(mult = c(0, 0.25))  # Make room for right-side labels
    ) +
    labs(
        title = "Hazard Ratios with 95% Confidence Intervals",
        x = "Hazard Ratio (log scale)",
        y = NULL
    ) +
    theme_minimal(base_size = 14) +
    theme(
        axis.text.y = element_text(size = 14),
        axis.text.x = element_text(size = 14),
        plot.title.position = "panel",
        plot.title = element_text(face = "bold", size = 14, hjust = 0.5),
        panel.grid.major.y = element_blank(),
        panel.grid.minor.x = element_blank(),
        plot.margin = margin(10, 140, 10, 10)  # top, right, bottom, left (in pts)
    )

}

# Saves multivariate analysis into filename
save_multivariate_logreg_results <- function(logreg_model, multivariate_filename) {
  # Tidy model with variable and level parsed
  multivariate_df <- tidy_plus_plus(
    logreg_model, 
    exponentiate = TRUE,
    variable_labels = multivar_df_pretty_names
  ) %>%
  mutate(
      OR_scaled = estimate / min(estimate, na.rm = TRUE),
      OR_rank = round(OR_scaled)
  )

  # Save to file
  write.csv(multivariate_df, multivariate_filename, row.names = FALSE)
  cat("Multivariate results saved to", multivariate_filename, "\n")

  return(multivariate_df)
}

# Plot forest plot from multivariate analysis
plot_multivariate_forest <- function(multivariate_df) {
    # Define color and label formatting
    multivariate_df <- multivariate_df %>%
    filter(statistic != 0) %>%
    mutate(
        Variable_pretty = multivar_forestplot_pretty_names[term],
        Variable_pretty = ifelse(is.na(Variable_pretty), term, Variable_pretty),
        sig = case_when(
        p.value < 0.001 ~ "***",
        p.value < 0.01 ~ "**",
        p.value < 0.05 ~ "*",
        TRUE ~ ""
        ),
        or_label = sprintf("%.2f (%.2f–%.2f)", estimate, conf.low, conf.high),
        Variable_labeled = paste0(Variable_pretty, " ", sig),  # add asterisks here
        color_group = ifelse(estimate >= 1, "estimate > 1", "estimate < 1")
    ) %>%
    arrange(estimate) %>%
    mutate(Variable_labeled = factor(Variable_labeled, levels = unique(Variable_labeled)))

    # Plot
    ggplot(multivariate_df, aes(x = estimate, y = Variable_labeled)) +
    geom_point(aes(color = color_group), size = 3) +
    geom_errorbarh(aes(xmin = conf.low, xmax = conf.high), height = 0.25) +
    geom_vline(xintercept = 1, linetype = "dashed", color = "gray50") +
    scale_color_manual(
        values = c("estimate > 1" = "lightblue", "estimate < 1" = "hotpink"),
        guide = "none"
    ) +
    scale_x_continuous(
        trans = "log10",
        breaks = c(0.5, 1, 2, 4),
        labels = c("0.5", "1", "2", "4")
    ) +
    labs(
        title = "Odds Ratios with 95% Confidence Intervals",
        x = "Odds Ratio (log scale)",
        y = NULL
    ) +
    theme_minimal(base_size = 12) +
    theme(
        axis.text.y = element_text(size = 14),
        axis.text.x = element_text(size = 12),
        plot.title.position = "plot",             # Title alignment
        plot.title = element_text(face = "bold", size = 14, hjust = 0.5),  # Centered title
        panel.grid.major.y = element_blank(),
        panel.grid.minor.x = element_blank()
    )
}

# Gets risk estimate from coxph
calculate_risk_from_coxph <- function(cox_model, validation_set, horizon_months = 60) {
  baseline_hazard <- basehaz(cox_model, centered = FALSE)
  H0_t <- approx(baseline_hazard$time, baseline_hazard$hazard, xout = horizon_months)$y
  
  linear_predictor <- predict(cox_model, newdata = validation_set, type = "lp")
  H_t_X <- H0_t * exp(linear_predictor)
  risk <- 1 - exp(-H_t_X)
  
  return(risk)
}

# Gets risk estimate from logistic regression
calculate_risk_from_logreg <- function(model, validation_set) {  
  risk <- predict(model, newdata = validation_set, type = "response")
  return(risk)
}

# Gets actual event 
count_event <- function(validation_set, outcome, horizon_months = 60) {
  event <- as.numeric(validation_set$months_to_event <= horizon_months & validation_set[[outcome]] == 1)
  return(event)
}

generate_event_dataframe <- function(validation_set) {
    data.frame(
        time = validation_set$months_to_event,
        event_ugica = validation_set$ugica,
        event_escc = validation_set$ugica_ESCC,
        event_eac = validation_set$ugica_EAC,
        event_cgc = validation_set$ugica_CGC,
        event_ncgc = validation_set$ugica_NCGC,

        race = validation_set$race_clean,
        sex = validation_set$sex_missing,
        age_bucket = validation_set$age_bucket,
        visit_year_bucket = validation_set$visit_year_bucket,
        
        ugica_5yr = count_event(validation_set, "ugica"),
        escc_5yr = count_event(validation_set, "ugica_ESCC"),
        eac_5yr = count_event(validation_set, "ugica_EAC"),
        cgc_5yr = count_event(validation_set, "ugica_CGC"),
        ncgc_5yr = count_event(validation_set, "ugica_NCGC"),

        ugica_1yr = count_event(validation_set, "ugica", horizon_months = 12),
        escc_1yr = count_event(validation_set, "ugica_ESCC", horizon_months = 12),
        eac_1yr = count_event(validation_set, "ugica_EAC", horizon_months = 12),
        cgc_1yr = count_event(validation_set, "ugica_CGC", horizon_months = 12),
        ncgc_1yr = count_event(validation_set, "ugica_NCGC", horizon_months = 12),

        ugica_3yr = count_event(validation_set, "ugica", horizon_months = 36),
        escc_3yr = count_event(validation_set, "ugica_ESCC", horizon_months = 36),
        eac_3yr = count_event(validation_set, "ugica_EAC", horizon_months = 36),
        cgc_3yr = count_event(validation_set, "ugica_CGC", horizon_months = 36),
        ncgc_3yr = count_event(validation_set, "ugica_NCGC", horizon_months = 36)
    )
}

# Get sensitivity and specificity 
calculate_cm_by_percentile <- function(risk, event, threshold) {
    # Convert the continuous risk scores to binary predictions
    predicted_class <- ifelse(risk >= threshold, 1, 0)

    cm <- table(event, predicted_class)

    # Extracting the values from the confusion matrix
    TN <- cm[1, 1]
    FP <- cm[1, 2]
    FN <- cm[2, 1]
    TP <- cm[2, 2]

    # Sensitivity (True Positive Rate)
    sensitivity <- TP / (TP + FN)

    # Specificity (True Negative Rate)
    specificity <- TN / (TN + FP)

    # Positive Predictive Value (PPV) (Precision)
    ppv <- TP / (TP + FP)

    # Negative Predictive Value (NPV)
    npv <- TN / (TN + FN) 

    # Number Needed to Screen (NNS)
    # cer <- (TP + FN) / (TN + FP + FN + TP) # control event rate is cases/entire population 
    cer <- FN / (FN + TN) # control event rate is the number of cases in those not screened 
    ser <- TP / (TP + FP) # screened event rate is the number of cases found / those screened 
    aer <- ser - cer # absolute event reduction 
    nns <- 1/aer 

    # C-statistic (AUROC)
    roc_obj <- roc(event, risk)
    c_statistic <- auc(roc_obj)

    # Print the results
    cat("C-statistic (AUROC):", round(c_statistic, 3), "\n")
    cat("Sensitivity:", sensitivity, "\n")
    cat("Specificity:", specificity, "\n")
    cat("PPV:", ppv, "\n")
    cat("NPV:", npv, "\n")
    cat("NNS:", nns, "\n")
    print(cm)
}

# Plots ROC curve
plot_roc_gg <- function(event, risk) {
  roc_obj <- roc(event, risk, quiet = TRUE)
  df <- data.frame(
    FPR = 1 - roc_obj$specificities,
    TPR = roc_obj$sensitivities
  )
  auroc <- round(auc(roc_obj), 3)

  ggplot(df, aes(x = FPR, y = TPR)) +
    geom_line(color = "navyblue", size = 1.2) +  # Better color
    geom_abline(linetype = "dashed", color = "gray50") +
    annotate("text", x = 0.65, y = 0.05, label = paste("AUROC =", auroc),
             size = 5, hjust = 0, fontface = "italic") +
    labs(
      title = "Receiver Operating Characteristic (ROC) Curve",
      x = "False Positive Rate (1 - Specificity)",
      y = "True Positive Rate (Sensitivity)"
    ) +
    coord_equal() +
    theme_minimal(base_size = 16) +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold"),
      axis.title = element_text(face = "bold"),
      panel.grid.minor = element_blank(),
      plot.margin = margin(10, 60, 10, 10)  # top, right, bottom, left (in pts)
    )
}

# Plots precision-recall curve
plot_pr_gg <- function(event, risk) {
  pr <- pr.curve(scores.class0 = risk[event == 1], scores.class1 = risk[event == 0], curve = TRUE)
  df <- data.frame(Recall = pr$curve[, 1], Precision = pr$curve[, 2])
  aucpr <- round(pr$auc.integral, 2)

  ggplot(df, aes(x = Recall, y = Precision)) +
    geom_line(color = "darkgreen", size = 1.2) +
    annotate("text", x = 0.6, y = 0.4, label = paste("AUC-PR =", aucpr), size = 5, color = "red") +
    labs(title = "Precision-Recall Curve", x = "Recall", y = "Precision") +
    theme_minimal()
}

# Plots Kaplan-Meier survival curve
plot_km_gg <- function(df, group, ylim = c(0.915, 1.00)) {
  surv_obj <- Surv(time = df$time, event = df$event)
  fit <- survfit(surv_obj ~ group, data = df)

  g <- ggsurvplot(
    fit,
    data = df,
    risk.table = TRUE,
    pval = TRUE,
    conf.int = TRUE,
    xlab = "Months to Event",
    ylab = "Survival Probability",
    ylim = ylim,
    ggtheme = theme_minimal()
  )

  return(g$plot)
}
