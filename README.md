# Data extraction from Mount Sinai Data Warehouse 
1. Navigate to `/code`. Ensure `run_extraction.sh` is executable by running `chmod +x run_extraction.sh`. Then run `./run_extraction.sh "2020-01-01" "2020-12-31"` with the start date and end date. I recommend performing the extraction in batches by running multiple processes, ie. one process per year. You will prompted for your MSDW password. 
    - This script will run `create_batch_sql.py` to create sql files with smaller date ranges and then run `extract_batch.sql` to run those batched sql files. The results of each query will be stored in `../data/...csv.gz`. 
    - Unfortunately at the moment, there is no way to connect to MSDW from Minerva so we have to run the extraction locally in a background process in batches. You can do this by using `screen` or the "no hang up" command to run the batch extraction in the background `nohup ./run_extraction.sh "2020-01-01" "2020-12-31" &`. The process will continue to run even with your computer closed. 
    - To test one batch file with prespecified dates, run `python3 create_batch_sql.py --start_date 2012-01-01 --end_date 2012-12-31` to generate an edited version of main_sql to run the first batch ranging from 1/1/2012 to 12/31/2012. This will output a new sql file called `batch_2012-01-01_2012-12-31.sql`. 

# Data processing
1. Run `python clean_cancer_registry.py` to clean up the UGI cancer registry data and output the cleaned file as `ugicancer_registry_clean.csv`. This will classify the cancers into subtypes based on tumor site and histology. 
    - Some diagnosis dates are also not the full date, but only include the year. For those with only the year of diagnosis, Jan 1 YYYY was imputed. 
    - `ugicancer_registry_notclassified.csv` will also be created, this is a deidentified csv of all tumor site and histology ICDs that did not meet one of the four subtypes for further manual review to ensure no cases were missed. 

# Data analysis
