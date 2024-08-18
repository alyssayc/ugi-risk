Running `main.sql` in batches. 
1. `python create_batch_sql.py --start_date 2012-01-01 --end_date 2012-12-31` to generate an edited version of main_sql to run the first batch ranging from 1/1/2012 to 12/31/2012. This will output a new sql file called `batch_2012-01-01_2012-12-31.sql`.
2. Run `batch_2012-01-01_2012-12-31.sql` in DBeaver. This will take time. Export the data and save the output file as `data_yyyymmdd_yyyymmdd.csv`. This step will also take multiple minutes. 
3. Compress the files from .csv. to .csv.gz for better data storage and efficiency. This will take some time.  
4. Navigate to `/data` and run `ls | grep -E '^data_[0-9]{8}_[0-9]{8}.csv.gz' > all_data_files.txt` on the command-line to export all the .csv filenames into one text file. 





## How to get concept IDs for lab values 
Credit: Farhan Mahmood from MSDW team

Notes: 
- `measurement.measurement_source_concept_id` = Epic's LRR lab components 
- `measurement.measurement_concept_id` = Symedical LOINC code mappings for lab components
- the `measurement` table is *huge* (>1 billion records) so using the LIKE operator on that table results in terrible performance. 
