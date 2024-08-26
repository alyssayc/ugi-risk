import argparse
from pathlib import Path

# Define directory path variable
directory = Path('./../sql/')

# Define main query filename and how to name updated queries 
query_file = 'main.sql'

def read_sql_template(file_path):
    with open(file_path, 'r') as file:
        sql_template = file.read()
    return sql_template

def update_date_range(sql_template, start_date, end_date):
    # Use str.format to replace placeholders with actual values
    updated_sql = sql_template.format(start_date=start_date, end_date=end_date)
    return updated_sql

def save_updated_sql(updated_sql, output_file_path):
    with open(output_file_path, 'w') as file:
        file.write(updated_sql)

def main(start_date, end_date):
    output_file = f'batch_{start_date}_{end_date}.sql'

    # Read the SQL template and converts to text 
    sql_template = read_sql_template(directory / query_file)
    
    # Update the SQL by replacing "start_date" with start_date and "end_date" with end_date
    updated_sql = update_date_range(sql_template, start_date, end_date)
    
    # Save the updated SQL query to a new file specified above 
    save_updated_sql(updated_sql, output_file)
    
    # Print a message to indicate the file has been saved
    print(f"Updated SQL query has been saved to {output_file}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Update SQL query with new date range.')
    parser.add_argument('--start_date', type=str, required=True, help='Start date in YYYY-MM-DD format')
    parser.add_argument('--end_date', type=str, required=True, help='End date in YYYY-MM-DD format')
    
    args = parser.parse_args()
    
    main(args.start_date, args.end_date)