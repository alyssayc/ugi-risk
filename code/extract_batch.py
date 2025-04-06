import pymssql
import pandas as pd
from datetime import datetime
import getpass
from pathlib import Path
import argparse
import os
import re
import glob

# Define directory 
sql_path = Path('./../sql/sql_batches/')  # Current directory where the batch SQL files are stored 
output_path = Path('./../data')  

# Set MSDW database configurations 
config = {
    "caboodle": {
        "username": "MSSMCAMPUS\\chena60",
        "host": "MSDW_PRD.mountsinai.org",
        "database": "omop",
        "port": "1433"
    },
}

def connect_to_database(password):
    # Connect to MSDW or Caboodle once
    conn = pymssql.connect(
        server=config['caboodle']['host'], 
        user=config['caboodle']['username'],
        password=password,
        database=config['caboodle']['database'],
        port=config['caboodle']['port']
    )

    return conn

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Year of data extraction')
    parser.add_argument('--year', type=str, required=True, help='Year of data extraction in YYYY format')
    parser.add_argument('--password', type=str, required=True, help='MSDW user password')
    
    args = parser.parse_args()
    extraction_year = args.year
    password = args.password

    conn = connect_to_database(password)

    # Create a cursor
    cursor = conn.cursor(as_dict=True)

    # Run data extraction for the year 
    # Loop through all files in the directory
    for sql_filename in os.listdir(sql_path):
        # Skip files that are not batch sql files 
        pattern = r'batch_.*\.sql'
        if not re.match(pattern, sql_filename): continue 

        # Skip files that are not the year we are extracting
        pattern = f'batch_{extraction_year}.*\.sql'
        if not re.fullmatch(pattern, sql_filename): 
            continue

        # For each SQL batch file, create the corresponding output filename 
        output_filename = re.sub(r'batch', 'data', sql_filename)
        output_filename = re.sub(r'\.sql$', '.csv.gz', output_filename)
        
        # Check to see if that data batch already exists, if so then skip 
        existing_file = glob.glob(os.path.join(output_path, output_filename))
        if existing_file:
            print(f"Data file {output_filename} already exists. Skipping...")
            continue 
        
        try:
            # Read the SQL file
            with open(sql_path / sql_filename, 'r') as file:
                sql_query = file.read()

            try:
                start_time = datetime.now() 
                print(f'Start time for {sql_filename}: {start_time.strftime("%Y-%m-%d %H:%M:%S")}')

                # Execute the SQL query
                print(f'Executing the query from {sql_filename}...')
                cursor.execute(sql_query)
                print('Executed the SQL query!')

                query_end_time = datetime.now()
                print(f'Query end time: {query_end_time.strftime("%Y-%m-%d %H:%M:%S")}')
                duration = (query_end_time - start_time).total_seconds()
                minutes = int(duration // 60)
                seconds = int(duration % 60)
                print(f'Total query time: {minutes} minutes and {seconds} seconds.')

                # Fetch the data
                print('Fetching the data!')
                data = cursor.fetchall()

                # Load the data into a pandas DataFrame
                print('Loading the data into a dataframe...')
                df = pd.DataFrame(data)

                # Save the result to a CSV file
                df.to_csv(output_path / output_filename, compression='gzip', index=False)
                print(f'Results saved as {output_path / output_filename}')

                # Calculate and print execution time 
                end_time = datetime.now()
                print(f'End time: {end_time.strftime("%Y-%m-%d %H:%M:%S")}')
                duration = (end_time - start_time).total_seconds()
                minutes = int(duration // 60)
                seconds = int(duration % 60)
                print(f'Total execution time: {minutes} minutes and {seconds} seconds.\n\n')
                
            except Exception as e:
                print(f"Error executing {sql_filename}: {e}\n\n")

        # Catch errors related to the SQL file or database connection
        except Exception as e:
            print(f"Error with file {sql_filename}: {e}")

    # # Close the connection after all queries are processed
    # conn.close()
    # print('Connection closed.')

