Data extraction - how to run `main.sql` in digestible batches and apply inclusion and exclusion criteria to generate a cohort for analysis. 
1. Navigate to `/sql` and edit `run_extraction.sh` with the start date and end date of the analysis. Edit your MSDW password. Ensure `run_extraction.sh` is executable by running `chmod +x run_extraction.sh`. This script will run `create_batch_sql.py` to create sql files with smaller date ranges and then run `extract_batch.sql` to run those batched sql files. The results of each query will be stored in `../data/...csv.gz`. 
    - To allow the script to run in the background, use the no hang up command: `nohup ./run_extraction.sh &`. Can assess progress with `tail -f nohup.out`. After your data extraction for that batch has completed, your data will be stored in `../data/...csv.gz` that you specified above. 
    - Note to test one batch file with prespecified dates, run `python create_batch_sql.py --start_date 2012-01-01 --end_date 2012-12-31` to generate an edited version of main_sql to run the first batch ranging from 1/1/2012 to 12/31/2012. This will output a new sql file called `batch_2012-01-01_2012-12-31.sql`.
3. To compile all the data files into one text file for us to feed into future files as input, navigate to `/data` and run `ls | grep -E '^data_20[0-9]{2}-[0-9]{2}-[0-9]{2}_20[0-9]{2}-[0-9]{2}-[0-9]{2}\.csv\.gz$' > all_data_files.txt` 
5. Navigate to `/data` and run `python3 create_cohort.py`. 

## How to get concept IDs for lab values 
Credit: Farhan Mahmood from MSDW team

Notes: 
- `measurement.measurement_source_concept_id` = Epic's LRR lab components 
- `measurement.measurement_concept_id` = Symedical LOINC code mappings for lab components
- the `measurement` table is *huge* (>1 billion records) so using the LIKE operator on that table results in terrible performance. 