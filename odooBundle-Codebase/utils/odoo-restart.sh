#! /bin/bash
#
# odoo_restart.sh
# Script to restart odoo with specified parameters using docker-compose.override.yml
# © 2024 Andrew Shen <wildfootw@hoschoc.com>
#
# Distributed under the same license as odooBundle-Codebase.
#

# Function to display usage
usage() {
    echo "Usage: $0 [odoo command parameters]"
    echo "Example:"
    echo "  $0"
    echo "  $0 -u estate"
    echo "  $0 -u estate --dev xml"
    exit 1
}

# Check if help is requested
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
fi

# Step 1: Stop the odoo container
echo "Stopping odoo container..."
docker-compose stop odoo
if [ $? -ne 0 ]; then
    echo "Error: Failed to stop odoo container."
    exit 1
fi

# Step 2: Create docker-compose.override.yml with the specified command
# If no parameters are provided, use the default 'odoo' command
if [ "$#" -gt 0 ]; then
    echo "Creating docker-compose.override.yml with the following command: odoo $@"
    CMD="odoo $@"
else
    echo "Creating docker-compose.override.yml with the default command: odoo"
    CMD="odoo"
fi

cat > docker-compose.override.yml <<EOF
services:
  odoo:
    command: $CMD
EOF

# Step 3: Start the odoo container with the override
echo "Starting odoo container with updated command..."
docker-compose up -d odoo
if [ $? -ne 0 ]; then
    echo "Error: Failed to start odoo container."
    # Cleanup override file before exiting
    rm -f docker-compose.override.yml
    exit 1
fi

# Optional: Wait for a few seconds to allow odoo to initialize
echo "Waiting for odoo to initialize..."
sleep 10

# Step 4: Remove the docker-compose.override.yml file
echo "Removing docker-compose.override.yml..."
rm -f docker-compose.override.yml

echo "odoo has been restarted with the specified parameters."

