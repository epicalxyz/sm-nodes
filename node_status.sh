#!/bin/bash

# Function to display countdown
countdown() {
    local seconds=$1
    while [ $seconds -gt 0 ]; do
        printf "\rNext update in %2d seconds..." $seconds
        sleep 1
        : $((seconds--))
    done
    printf "\r                               \r"
}

# Function to get latest eligibilities from EventsStream
get_eligibilities() {
    local ip=$1
    local port=$2
    local output=$(timeout 5s grpcurl --plaintext "$ip:$port" spacemesh.v1.AdminService.EventsStream)
    local epoch=$(echo "$output" | grep -o '"epoch": [0-9]*' | tail -1 | awk '{print $2}')
    local layer=$(echo "$output" | grep -o '"layer": [0-9]*' | tail -1 | awk '{print $2}')
    if [ -n "$epoch" ] && [ -n "$layer" ]; then
        echo "$epoch,$layer"
    else
        echo "N/A,N/A"
    fi
}

# Function to read JSON and execute command for each entry
process_nodes() {
    # Clear the screen
    clear

    # Print the table header
    printf "%-10s %-7s %-10s %-13s %-10s %-15s %-13s %-15s\n" "NodeName" "Peers" "IsSynced" "SyncedLayer" "TopLayer" "VerifiedLayer" "EligibEpoch" "EligibLayer"
    printf "%-10s %-7s %-10s %-13s %-10s %-15s %-13s %-15s\n" "--------" "-----" "--------" "-----------" "--------" "-------------" "-----------" "-----------"

    # Read the JSON file line by line
    while IFS=, read -r name ip port1 port2; do
        # Remove any leading/trailing whitespace and quotes
        name=$(echo "$name" | tr -d '"' | xargs)
        ip=$(echo "$ip" | tr -d '"' | xargs)
        port1=$(echo "$port1" | tr -d '"' | xargs)
        port2=$(echo "$port2" | tr -d '"' | xargs)

        # Run the grpcurl command and store the output
        output=$(grpcurl -plaintext "$ip:$port1" spacemesh.v1.NodeService.Status)

        # Extract the required values using grep and cut
        connectedPeers=$(echo "$output" | grep '"connectedPeers"' | cut -d'"' -f4)
        isSynced=$(echo "$output" | grep '"isSynced"' | cut -d':' -f2 | tr -d ' ,')
        syncedLayer=$(echo "$output" | grep -A1 '"syncedLayer"' | grep 'number' | cut -d':' -f2 | tr -d ' ,')
        topLayer=$(echo "$output" | grep -A1 '"topLayer"' | grep 'number' | cut -d':' -f2 | tr -d ' ,')
        verifiedLayer=$(echo "$output" | grep -A1 '"verifiedLayer"' | grep 'number' | cut -d':' -f2 | tr -d ' ,')

        # Get eligibilities
        IFS=',' read -r eligibEpoch eligibLayer <<< $(get_eligibilities "$ip" "$port2")

        # Print the values in table format
        printf "%-10s %-7s %-10s %-13s %-10s %-15s %-13s %-15s\n" "$name" "$connectedPeers" "$isSynced" "$syncedLayer" "$topLayer" "$verifiedLayer" "$eligibEpoch" "$eligibLayer"
    done < nodes.json

    echo ""
}

# Main loop
while true; do
    process_nodes
    countdown 60
done
