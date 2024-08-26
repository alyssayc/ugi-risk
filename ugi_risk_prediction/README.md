Data extraction - how to run `main.sql` in batches
1. `python create_batch_sql.py --start_date 2012-01-01 --end_date 2012-12-31` to generate an edited version of main_sql to run the first batch ranging from 1/1/2012 to 12/31/2012. This will output a new sql file called `batch_2012-01-01_2012-12-31.sql`.
2. Edit `extract_batch.py`. Change the `sql_file_name` and `output_file_name` to the batch sql file you generated above. 
3. `python3 extract_batch.py`. Enter your MSDW password. This step will also take about 30 minutes depending on how large your batch is. 
4. After your data extraction for that batch has completed, your data will be stored in `../data/...csv.gz` that you specified above. Repeat the steps above for all batches. 
5. Navigate to `/data` and run `ls | grep -E '^data_[0-9]{8}_[0-9]{8}.csv.gz' > all_data_files.txt` on the command-line to export all the .csv filenames into one text file. 

## How to get concept IDs for lab values 
Credit: Farhan Mahmood from MSDW team

Notes: 
- `measurement.measurement_source_concept_id` = Epic's LRR lab components 
- `measurement.measurement_concept_id` = Symedical LOINC code mappings for lab components
- the `measurement` table is *huge* (>1 billion records) so using the LIKE operator on that table results in terrible performance. 
