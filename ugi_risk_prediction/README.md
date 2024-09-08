Data extraction - how to run `main.sql` in batches
1. `python create_batch_sql.py --start_date 2012-01-01 --end_date 2012-12-31` to generate an edited version of main_sql to run the first batch ranging from 1/1/2012 to 12/31/2012. This will output a new sql file called `batch_2012-01-01_2012-12-31.sql`.
2. Edit `run_extraction.sh` with the sql filenames of the batch sql file you generated above. The second silent argument is the output filenames. Ensure `run_extraction.sh` is executable by running `chmod +x run_extraction.sh`. 
3. Run `./run_extraction.sh`. Enter your MSDW password. This step will also take about 30 minutes - 1hr. depending on how large your batch is. You will need to enter your MSDW password for each batch extraction.
4. After your data extraction for that batch has completed, your data will be stored in `../data/...csv.gz` that you specified above. Repeat the steps above for all batches. 
5. Navigate to `/data` and run `./create_cohort.sh`. Ensure `run_extraction.sh` is executable by running `chmod +x create_cohort.sh`. This will compile all the batched data into one text file called 'all_data_files.txt'. Then it will read the data in batches, apply inclusion and exclusion criteria and merge with UGI cancer registry. 

## How to get concept IDs for lab values 
Credit: Farhan Mahmood from MSDW team

Notes: 
- `measurement.measurement_source_concept_id` = Epic's LRR lab components 
- `measurement.measurement_concept_id` = Symedical LOINC code mappings for lab components
- the `measurement` table is *huge* (>1 billion records) so using the LIKE operator on that table results in terrible performance. 
