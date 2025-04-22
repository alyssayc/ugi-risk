# Save the current directory
current_dir=$(pwd)

# Clean up UGI cancer registry data and get cancer subtypes 
python clean_cancer_registry.py

# Navigate to the ../data directory or exit the script if the directory doesn't exist
cd ../data || exit

# Run ls | grep to get all the batched data files in one text file 
ls | grep -E '^data_20[0-9]{2}-[0-9]{2}-[0-9]{2}_20[0-9]{2}-[0-9]{2}-[0-9]{2}\.csv\.gz$' > all_data_files.txt

# Return to the original directory 
cd "$current_dir" || exit

# Merge with UGI registry, apply inclusion criteria, apply exclusion criteria 
python create_cohort.py \
    --data_txt_file all_data_files.txt \
    --ugi_file ugicancer_registry_clean.csv \
