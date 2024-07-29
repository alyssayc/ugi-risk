Running `main.sql` in batches. 
1. `python create_batch_sql.sql --start_date 2012-01-01 --end_date 2012-12-31` to generate an edited version of main_sql to run the first batch ranging from 1/1/2012 to 12/31/2012. This will output a new sql file called `batch_2012-01-01_2012-12-31.sql`.
2. Run `batch_2012-01-01_2012-12-31.sql`
