#!/bin/bash

# Input start and end dates (format: YYYY-MM-DD)
start_date=$1 #"2011-01-01"
end_date=$2 #"2013-12-31"

# Convert start and end dates to date objects for manipulation
current_date=$start_date
final_date=$end_date

# Loop until we reach the final date
while [[ "$current_date" < "$final_date" ]]; do
    # Calculate the end date for the current period (6 months later)
    # end_of_period=$(date -I -d "$current_date + 6 months") #Linux-based systems
    end_of_period=$(date -v+15d -j -f "%Y-%m-%d" "$current_date" "+%Y-%m-%d") #Mac-based systems #1m
    
    # Make sure we don't exceed the final date
    if [[ "$end_of_period" > "$final_date" ]]; then
        end_of_period=$final_date
    fi

    # Run the Python script with the calculated start and end dates
    # This will output sql files for each specified time range 
    echo "Running python create_batch_sql.py --start_date $current_date --end_date $end_of_period"
    python create_batch_sql.py --start_date "$current_date" --end_date "$end_of_period"

    # Move to the next period (6 months ahead)
    current_date=$end_of_period
    # For the next loop, we start from the first day of the new period
    # current_date=$(date -I -d "$current_date + 1 day") #Linux-based systems
    current_date=$(date -v+1d -j -f "%Y-%m-%d" "$current_date" "+%Y-%m-%d") #MacOS systems 
done

# Get MSDW user password 
echo "Enter your Mount Sinai Data Warehouse password to connect to the database: "
read -s password 

# Function to check VPN connection by pinging
check_vpn_connection() {
    # Ping the VPN server or DNS (this is a simple way to test if the VPN is up)
    if ping -c 1 8.8.8.8 &>/dev/null; then
        echo "VPN is connected."
    else
        echo "VPN is not connected, please connect to access MSDW. Exiting script..."
        exit 1
    fi
}

# Run the check and wait for 5 mins before the next check
while true; do
    check_vpn_connection
    sleep 300  # Wait 10 minutes before checking again
done &  # Run this in the background

# Loop through the batch sql files, execute the sql files, and store the data in data/data_***.csv.gz 
# Extract data via multiple processes by year 

# Split the start_date and end_date by "-" and get the first item (the year)
start_year=$(echo $start_date | cut -d'-' -f1)
end_year=$(echo $end_date | cut -d'-' -f1)

# Loop from the start_year_int to end_year_int and print each year
for extraction_year in $(seq $start_year $end_year); do
    python extract_batch.py --year "$extraction_year" --password "$password"
done
