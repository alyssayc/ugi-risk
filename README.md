# Data extraction from Mount Sinai Data Warehouse 
1. Navigate to `/sql` and edit `run_extraction.sh` with the start date and end date of the analysis (1/1/2011 - 12/31/2023). In `extract_batch.py`, enter your MSDW password. Ensure `run_extraction.sh` is executable by running `chmod +x run_extraction.sh`. Then run `nohup ./run_extraction.sh &` to run the process in the background. 
    - This script will run `create_batch_sql.py` to create sql files with smaller date ranges and then run `extract_batch.sql` to run those batched sql files. The results of each query will be stored in `../data/...csv.gz`. 
    - Unfortunately at the moment, there is no way to connect to MSDW from Minerva so we have to run the extraction locally in a background process in batches. You can do this by using the "no hang up" command to run the batch extraction in the background `nohup ./run_extraction.sh &`. The process will continue to run even with your computer closed. 
    - To test one batch file with prespecified dates, run `python3 create_batch_sql.py --start_date 2012-01-01 --end_date 2012-12-31` to generate an edited version of main_sql to run the first batch ranging from 1/1/2012 to 12/31/2012. This will output a new sql file called `batch_2012-01-01_2012-12-31.sql`. To extract one batch file run `python3 extract_batch.py --sqlfile batch_2012-01-01_2012-12-31.sql`

# Data analysis
