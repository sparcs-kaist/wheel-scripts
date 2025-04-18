#!/bin/bash

# SPARCS VM Script Runner
# This script downloads and executes setup-script.sh in a specified VM

# Function to display usage instructions and exit
print_usage_and_exit() {
    echo "========================================"
    echo "           VM Script Runner             "
    echo "========================================"
    echo "Usage: $0 <VMID> [--docker]"
    echo "Example: $0 100 --docker"
    echo "----------------------------------------"
    echo "Arguments:"
    echo "  VMID       : The ID of the VM to run the script in"
    echo "  --docker   : Pass --docker flag to the setup script"
    echo "========================================"
    exit 1
}

# Check if required arguments are provided
if [ "$#" -lt 1 ]; then
    print_usage_and_exit
fi

# Variables
VMID=$1
DOCKER_FLAG=""
SCRIPT_URL="https://raw.githubusercontent.com/sparcs-kaist/wheel-scripts/refs/heads/main/setup-script.sh"

# Check for --docker flag
if [ "$2" = "--docker" ]; then
    DOCKER_FLAG="-- --docker"
fi

# Show the configuration
echo "=== Script Configuration ==="
echo "----------------------------------------"
echo "VM ID: ${VMID}"
echo "Docker Flag: ${DOCKER_FLAG:-Not Set}"
echo "Script URL: ${SCRIPT_URL}"
echo "----------------------------------------"

# Temporary file to store the downloaded script
SCRIPT_FILE="/tmp/temp_script_$VMID.sh"

# Check for required tools
echo "=== Checking Required Tools ==="
if ! command -v jq &> /dev/null; then
    echo "Installing jq..."
    apt-get update && apt-get install -y jq
fi

# Check and install wget in VM
echo "=== Setting up VM Environment ==="
if ! qm guest exec "$VMID" command -v wget &> /dev/null; then
    echo "Installing wget in VM..."
    qm guest exec "$VMID" apt-get update | jq
    qm guest exec "$VMID" apt-get install -- -y wget | jq
fi

# Download and execute script
echo "=== Downloading Setup Script ==="
qm guest exec "$VMID" wget -- -O ${SCRIPT_FILE} ${SCRIPT_URL} | jq

echo "=== Executing Setup Script ==="
echo "Running setup script with timeout of 600 seconds..."
qm guest exec --timeout 600 "$VMID" bash ${SCRIPT_FILE} ${DOCKER_FLAG} | jq

# Cleanup and reboot
echo "=== Cleanup and Reboot ==="
echo "Removing temporary script file..."
qm guest exec "$VMID" rm ${SCRIPT_FILE} | jq
echo "Rebooting VM..."
qm reboot "$VMID"

echo "=== Setup Complete ==="
echo "Script executed successfully in VM with ID $VMID"
