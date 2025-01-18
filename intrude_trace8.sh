#!/bin/bash

# YAML Configuration File
CONFIG_FILE="intrude_trace_config.yaml"
CHAIN_OF_CUSTODY_FILE="chain_of_custody.txt"
SURICATA_PID=""
APACHE_SPOT_PID=""

# Function to load YAML configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        cat "$CONFIG_FILE"
    else
        echo "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
}

# Function to load cases from YAML
load_cases() {
    if [ -f "cases.yaml" ]; then
        cat cases.yaml
    else
        echo "cases:"
    fi
}

# Function to add a new case to YAML
add_case_interactive() {
    echo "Enter details for the new case:"
    read -p "Case Name: " case_name
    read -p "Description: " description
    read -p "Assigned User: " assigned_user
    read -p "Priority: " priority
    read -p "Tags (comma-separated): " tags
    read -p "Due Date (YYYY-MM-DDTHH:mm:SSZ): " due_date
    local new_case=$(cat <<EOF
- case_id: $(($(load_cases | grep -c "1") + 1))
  case_name: "$case_name"
  description: "$description"
  status: "investigating"
  assigned_user: "$assigned_user"
  created_at: "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  priority: "$priority"
  tags: [$(echo "$tags" | sed 's/,/","/g' | sed 's/^/"/' | sed 's/$/"/')]
  due_date: "$due_date"
EOF
    )

    if [ -f "cases.yaml" ]; then
        sed -i '/cases:/d' cases.yaml  # Remove existing "cases:" line
        echo "$(load_cases)" > cases.yaml  # Save existing cases
    else
        echo "cases:" > cases.yaml         # Create a new YAML file if it doesn't exist
    fi

    echo "$new_case" >> cases.yaml         # Add new case
}

# Function to view cases
view_cases() {
    load_cases
}

# Function to add a new item to the chain of custody
add_item() {
    echo "Adding item to the chain of custody..."
    read -p "Enter item name: " item_name
    read -p "Enter description: " description
    read -p "Enter initial custodian: " initial_custodian
    read -p "Enter transfer reason: " transfer_reason
    read -p "Enter destination custodian: " destination_custodian

    echo "  Description: $description" >> "$CHAIN_OF_CUSTODY_FILE"
    echo "  Initial Custodian: $initial_custodian" >> "$CHAIN_OF_CUSTODY_FILE"
    echo "  Transfer Reason: $transfer_reason" >> "$CHAIN_OF_CUSTODY_FILE"
    echo "  Destination Custodian: $destination_custodian" >> "$CHAIN_OF_CUSTODY_FILE"
    echo "  Transfer Date: $(date)" >> "$CHAIN_OF_CUSTODY_FILE"

    echo "Item added successfully."
}

# Function to view the chain of custody
view_chain_of_custody() {
    echo "Viewing chain of custody..."
    if [ -f "$CHAIN_OF_CUSTODY_FILE" ]; then
        cat "$CHAIN_OF_CUSTODY_FILE"
    else
        echo "Chain of custody is empty."
    fi
}

# Function to start Suricata
start_suricata() {
    echo "Starting Suricata on interface enp0s3..."
    gnome-terminal -- sudo suricata -c /etc/suricata/suricata.yaml -i enp0s3
    echo "Suricata started."
}

# Function to stop Suricata
stop_suricata() {
    if [ -n "$SURICATA_PID" ]; then
        echo "Stopping Suricata..."
        sudo kill $SURICATA_PID
        echo "Suricata stopped."
        SURICATA_PID=""
    else
        echo "Suricata is not running."
    fi
}

# Function to start Apache Spot
start_apache_spot() {
    local config=$(load_config)
    local apache_spot_enabled=$(echo "$config" | awk '/apache_spot:/ {print $2}')

    if [ "$apache_spot_enabled" != "enabled: true" ]; then
        echo "Apache Spot is not enabled in the configuration."
        exit 1
    fi

    local docker_image=$(echo "$config" | awk '/docker_image:/ {print $2}')
    local port_mapping=$(echo "$config" | awk '/port_mapping:/ {print $2}')

    echo "Starting Apache Spot..."
    docker run -it -p "$port_mapping" "$docker_image" &
    APACHE_SPOT_PID=$!
    echo "Apache Spot started successfully. PID: $APACHE_SPOT_PID"
}

# Function to view Apache logs
view_apache_logs() {
    echo "Viewing Apache logs..."
    sudo tail -f /var/log/apache2/access.log
}

# Function to view Suricata logs
view_suricata_logs() {
    echo "Viewing Suricata logs..."
    sudo tail -f /var/log/suricata/suricata.log
}

# Main function
main() {
    while true; do
        clear
        echo "INTRUDE TRACE - Enhancing Cyber Intrusion Investigations"
        echo "1. Add Case"
        echo "2. View Cases"
        echo "3. Add Item to Chain of Custody"
        echo "4. View Chain of Custody"
        echo "5. Start Suricata"
        echo "6. Stop Suricata"
        echo "7. View Suricata Logs"
        echo "8. Start Apache Spot"
        echo "9. View Apache Logs"
        echo "10. Exit"

        read -p "Enter your choice: " choice

        case $choice in
            1)
                add_case_interactive
                ;;
            2)
                view_cases
                ;;
            3)
                add_item
                ;;
            4)
                view_chain_of_custody
                ;;
            5)
                start_suricata
                ;;
            6)
                stop_suricata
                ;;
            7)
                view_suricata_logs
                ;;
            8)
                start_apache_spot
                ;;
            9)
                view_apache_logs
                ;;
            10)
                echo "Exiting..."
                exit 0
                ;;
            *)
                echo "Invalid choice. Please enter a valid option"
                ;;
        esac

        read -p "Press Enter to continue..."
    done
}

# Run the main function
main
