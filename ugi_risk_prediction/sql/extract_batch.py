import pymssql
import pandas as pd
from datetime import datetime
import getpass
from pathlib import Path
import argparse

# Set up command-line argument parsing
parser = argparse.ArgumentParser(description='Run a SQL query and save the results to a gzip-compressed CSV file.')
parser.add_argument('sql_file_name', type=str, help='Path to the SQL file to be executed.')
parser.add_argument('output_file_name', type=str, help='Path to the output gzip-compressed CSV file.')

args = parser.parse_args()

sql_file_name = args.sql_file_name
output_file_name = args.output_file_name
output_path = Path(__file__).resolve().parent.parent / 'data'  # Navigates up two parents from the current file and into the data dir

config = {
    "caboodle": {
        "username": "MSSMCAMPUS\\chena60",
        "host": "MSDW_PRD.mountsinai.org",
        "database": "omop",
        "port": "1433"
    },
}

# Read the SQL file  
with open(sql_file_name, 'r') as file:
    sql_query = file.read()

# Prompt user for their password 
password = getpass.getpass(prompt='Enter your password: ')

# Connect to MSDW or Caboodle
conn = pymssql.connect(server=config['caboodle']['host'], user=config['caboodle']['username'],
                       password=password,
                       database=config['caboodle']['database'],
                       port=config['caboodle']['port'])

# Create a cursor and execute the query
cursor = conn.cursor(as_dict=True)

try: 
    start_time = datetime.now() 
    print(f'Start time: {start_time.strftime("%Y-%m-%d %H:%M:%S")}')

    # Execute the SQL query
    print(f'Executing the query {sql_file_name}')
    cursor.execute(sql_query)
    print('Executed the SQL query!')

    # Fetch the data
    print('Fetching the data!')
    data = cursor.fetchall()

    # Load the data into a pandas DataFrame
    print('Loading the data into a dataframe...')
    df = pd.DataFrame(data)
    
    # Save the result to a CSV file
    df.to_csv(output_path / output_file_name, compression='gzip', index=False)
    print(f'Results saved as {output_path / output_file_name}')

finally:
    # Close the connection
    conn.close()

end_time = datetime.now()
print(f'End time: {end_time.strftime("%Y-%m-%d %H:%M:%S")}')
duration = (end_time - start_time).total_seconds()
minutes = int(duration // 60)
seconds = int(duration % 60)
print(f'Total execution time: {minutes} minutes and {seconds} seconds.')
