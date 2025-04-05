#!/bin/bash

# Input start and end dates (format: YYYY-MM-DD)
start_date="2020-01-01"
end_date="2020-12-31"

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

# Run the check and wait for 10 seconds before the next check
while true; do
    check_vpn_connection
    sleep 300  # Wait 5 minutes before checking again
done &  # Run this in the background

# Loop through the batch sql files, execute the sql files, and store the data in data/data_***.csv.gz 
python extract_batch.py 
