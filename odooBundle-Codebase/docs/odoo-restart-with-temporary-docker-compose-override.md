# Temporary Odoo Command Override Using `docker-compose.override.yml`

This guide explains how to temporarily override the command of your odoo service using `docker-compose.override.yml`. This method allows you to run specific odoo commands without permanently altering your main `docker-compose.yml` configuration. We'll also include a script to automate the process of stopping the service, applying the override, and starting the service again.

## Problem Statement

You need to execute a specific odoo command:

    odoo -d rd-demo -u estate

You want to run this command within your Docker environment using `docker-compose`, ensuring that all existing configurations (like ports, volumes, and environment variables) are maintained. You also want to avoid creating new containers with unexpected names or missing configurations.

## Solution Overview

We'll use a `docker-compose.override.yml` file to temporarily override the command that the odoo service runs. This approach keeps your original `docker-compose.yml` intact and allows you to easily revert back after the command has executed.

Alternatively, you can use the provided script to automate this process, making it even easier.

## Step-by-Step Instructions

### 1. Use the Script to Apply the Override

Instead of manually creating the `docker-compose.override.yml` file, you can use the following script to automate the process. The script will:

1. Stop the odoo service.
2. Create the override file with the provided odoo command.
3. Restart the service with the new command.
4. Remove the override file after the service restarts.

#### Script: `./misc/odoo-restart.sh`

    ```bash
    #!/bin/bash

    # Script to restart odoo with specified parameters using docker-compose.override.yml

    # Function to display usage
    usage() {
        echo "Usage: $0 [odoo command parameters]"
        echo "Example:"
        echo "  $0 -u estate"
        echo "  $0 -d rd-demo -u estate"
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
        rm -f docker-compose.override.yml
        exit 1
    fi

    # Optional: Wait for a few seconds to allow odoo to initialize
    echo "Waiting for odoo to initialize..."
    sleep 10

    # Step 4: Remove the docker-compose.override.yml file
    echo "Removing docker-compose.override.yml..."
    rm -f docker-compose.override.yml

    echo "Odoo has been restarted with the specified parameters."
    ```

### 2. Running the Script

You can execute the script with the parameters for the odoo command you want to run. For example:

    ```bash
    ./misc/odoo-restart.sh -u estate
    ```

Or specify the database and update the module:

    ```bash
    ./misc/odoo-restart.sh -d rd-demo -u estate
    ```

The script will automatically stop the odoo service, apply the new command, and start the service. Afterward, it will remove the override file, so the next time you start the services, they will use the original command.

### 3. Monitor the Service (Optional)

You can check the logs to ensure that the command is executing as expected:

    ```bash
    docker-compose logs -f odoo
    ```

This will allow you to monitor the progress of the command.

### 4. Verify the Service is Running Normally

Check the status of your containers to ensure everything is running as expected:

    ```bash
    docker-compose ps
    ```

## Additional Notes

- **Data Persistence:** Ensure that your volumes are correctly configured in `docker-compose.yml` so that data persists between container restarts.
- **Backups:** Before performing database updates or module installations, it's recommended to back up your database.
- **Environment Variables:** Any environment variables specified in your `docker-compose.yml` will still be in effect.
- **Service Names:** Make sure to use the correct service names as defined in your `docker-compose.yml` when running commands.

## Conclusion

Using `docker-compose.override.yml` is an effective way to temporarily change the command for a service without altering your main `docker-compose.yml` file. With the added script, you can streamline the process and easily run custom odoo commands while maintaining all existing configurations.

