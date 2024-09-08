#!/bin/bash

# Export all the .csv filenames into one text file to be read 
ls | grep -E '^data_[0-9]{8}_[0-9]{8}.csv.gz'| sort -r > all_data_files.txt

# Apply inclusion and exclusion criteria and merge with UGI cancer registry
python3 create_cohort.py