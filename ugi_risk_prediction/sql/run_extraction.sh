#!/bin/bash

# Can add as many command lines as needed 
# python3 create_batch_sql.py --start_date 2011-07-01 --end_date 2011-12-31
python3 extract_batch.py batch_2011-07-01_2011-12-31.sql data_20110701_20111231.csv.gz

# python3 create_batch_sql.py --start_date 2023-04-01 --end_date 2023-09-30
python3 extract_batch.py batch_2023-04-01_2023-09-30.sql data_20230401_2230930.csv.gz

# python3 extract_batch.py batch_2016-01-01_2016-12-31.sql data_20160101_20161231.csv.gz
# python3 extract_batch.py batch_2017-01-01_2017-12-31.sql data_20170101_20171231.csv.gz