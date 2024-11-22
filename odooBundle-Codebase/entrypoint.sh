#!/bin/bash

# Define a header for all echo statements
HEADER="[entrypoint.sh]"
echo "$HEADER Running with PID $$ at $(date)"

# Define the path to odoo-bin
ODOO_BIN="/opt/odoo/core/odoo-bin"

# Function to combine general and sensitive config files into a single config If the environment variable CONF_OVERRIDE_WITH_SECURE is set to "true", it merges the content of the general config file (/etc/odoo/odoo-general.conf) and the sensitive config file (/etc/odoo/odoo-sensitive.conf) into a single file (/etc/odoo/odoo.conf). This merged file will then be used by odoo during startup.
#
# If CONF_OVERRIDE_WITH_SECURE is not set or is set to "false", the function skips the merge process and continues using the default configuration that was either copied into the container during the Dockerfile build process (typically /etc/odoo/odoo.conf) or mounted into the container via docker-compose or similar methods. This ensures that sensitive configuration data is only included when explicitly enabled, and the system falls back to a default configuration if no override is needed.
function combine_general_and_sensitive_configs() {
    if [ "$CONF_OVERRIDE_WITH_SECURE" == "true" ]; then
        echo "$HEADER CONF_OVERRIDE_WITH_SECURE is set to 'true'. Proceeding with config merge..."

        # Verify both general and sensitive config files exist before merging
        if [ -f /etc/odoo/odoo-general.conf ] && [ -f /etc/odoo/odoo-sensitive.conf ]; then
            echo "$HEADER Found both general and sensitive config files."
            cat /etc/odoo/odoo-general.conf /etc/odoo/odoo-sensitive.conf > /etc/odoo/odoo.conf
            echo "$HEADER Config files merged into /etc/odoo/odoo.conf"
        else
            echo "$HEADER Error: One or both of the config files are missing. Merge aborted."
            exit 1
        fi

    # Handle invalid or missing values for CONF_OVERRIDE_WITH_SECURE
    elif [ -z "$CONF_OVERRIDE_WITH_SECURE" ]; then
        echo "$HEADER CONF_OVERRIDE_WITH_SECURE is not set. Using default config."
    else
        echo "$HEADER Warning: CONF_OVERRIDE_WITH_SECURE is set to an invalid value. Using default config."
    fi
}


# Call the function at the start
combine_general_and_sensitive_configs


# set the postgres database host, port, user and password according to the environment
# and pass them as arguments to the odoo process if not present in the config file
echo "$HEADER Setting up database connection parameters..."
: ${DB_HOST:=${POSTGRES_HOST:='db'}} # Sets DB_HOST to its current value, or to POSTGRES_HOST if available, or defaults to 'db'.
: ${DB_PORT:=${POSTGRES_PORT:=5432}}
: ${DB_USER:=${POSTGRES_USER:='odoo'}}
: ${DB_PASSWORD:=${POSTGRES_PASSWORD:='odoo'}}
: ${DB_NAME:=${POSTGRES_DB:='odoo'}}

DB_ARGS=()
# Adds the parameter (prefixed with "--") and its value to DB_ARGS, using config file value if available.
function check_config() {
    param="$1"
    value="$2"
    if grep -q -E "^\s*\b${param}\b\s*=" "$ODOO_RC" ; then
        value=$(grep -E "^\s*\b${param}\b\s*=" "$ODOO_RC" |cut -d " " -f3|sed 's/["\n\r]//g')
    fi;
    DB_ARGS+=("--${param}")
    DB_ARGS+=("${value}")
}
check_config "db_host" "$DB_HOST"
check_config "db_port" "$DB_PORT"
check_config "db_user" "$DB_USER"
check_config "db_password" "$DB_PASSWORD"

# This section handles different input arguments:
# - If the first argument is "odoo", it processes "scaffold" or runs Odoo with the provided arguments.
#   Additionally, it checks the PostgreSQL readiness and initializes the database if necessary.
# - For any other input, it directly executes the given command.

case "$1" in
    odoo)
        shift # Removes $1 ("odoo")

        if [[ "$1" == "scaffold" ]]; then
            echo "$HEADER Executing scaffold command: $ODOO_BIN $@"
            exec $ODOO_BIN "$@"

        else
            echo "$HEADER Checking PostgreSQL readiness..."
            check-db-status.py "${DB_ARGS[@]}" --timeout=30
            if [ $? -ne 0 ]; then
                echo "$HEADER PostgreSQL is not ready. Exiting."
                exit 1
            fi

            echo "$HEADER Executing: $ODOO_BIN $@ ${DB_ARGS[@]}"
            exec $ODOO_BIN "$@" "${DB_ARGS[@]}"

        fi
        ;;
    *)
        echo "$HEADER Executing custom command: $@"
        exec "$@"
        ;;
esac

exit 1

