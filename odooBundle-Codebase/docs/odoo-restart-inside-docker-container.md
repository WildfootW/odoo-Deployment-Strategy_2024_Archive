# Odoo Process Management Script

## Overview

This script was designed to gracefully stop an existing Odoo process and restart it with new parameters. The goal was to ensure the Odoo process would be stopped without terminating the entire Docker container, allowing for dynamic parameter updates.

### Script Design

1. **Check for Existing Odoo Process:**
   The script uses `pgrep` to find the running Odoo process by matching the exact binary path (`ODOO_BIN`). This ensures that we only target the correct process.

2. **Handle Multiple Processes:**
   If more than one Odoo process is found, the script will abort to prevent accidental termination of the wrong process.

3. **Graceful Shutdown:**
   The script sends a `SIGTERM` signal to allow the Odoo process to shut down gracefully. It then verifies whether the process has successfully stopped.

4. **Timeout Mechanism:**
   To ensure the process terminates in a reasonable amount of time, a 30-second timeout is implemented. If the Odoo process fails to stop within this time frame, the script exits with an error.

5. **Restart with New Parameters:**
   After successfully stopping the process, the script starts Odoo again, passing any new parameters.

### Code

    if [[ "$1" == "restart" ]]; then
        echo "$HEADER Stopping existing odoo process gracefully..."
    
        # Find the PID(s) of the running odoo process using the exact ODOO_BIN path
        PIDS=$(pgrep -f "^[p]ython3 $ODOO_BIN")
        if [ -z "$PIDS" ]; then
            echo "$HEADER No running odoo process found."
            exit 1
        fi
    
        PID_COUNT=$(echo "$PIDS" | wc -w) # Count the number of PIDs found
    
        if [ "$PID_COUNT" -gt 1 ]; then
            echo "$HEADER Multiple odoo processes found (PIDs: $PIDS). Aborting to prevent accidental termination."
            exit 1
        fi
    
        PID=$PIDS
        echo "$HEADER Found odoo process with PID: $PID"
    
        kill $PID # Send SIGTERM signal to allow graceful shutdown
    
        # Wait for the process to terminate gracefully
        echo "$HEADER Waiting for odoo process to stop..."
        TIMEOUT=30  # Timeout in seconds
        ELAPSED=0
        while kill -0 $PID 2>/dev/null; do
            if [ $ELAPSED -ge $TIMEOUT ]; then
                echo "$HEADER Failed to stop odoo process $PID within timeout."
                exit 1
            fi
            sleep 1
            ELAPSED=$((ELAPSED + 1))
        done
    
        echo "$HEADER odoo process $PID has been stopped."
    
        shift # Remove 'restart' from arguments
    
        echo "$HEADER Starting odoo with new parameters."
        echo "$HEADER Executing: $ODOO_BIN $@ ${DB_ARGS[@]}"
        exec $ODOO_BIN "$@" "${DB_ARGS[@]}"
    fi

### Key Considerations

- **Graceful Shutdown:** The script relies on `SIGTERM` to allow the Odoo process to clean up before shutting down. This ensures that no data corruption or incomplete transactions occur.
  
- **Process Timeout:** The script waits up to 30 seconds for the Odoo process to fully stop, ensuring that the system doesn’t hang indefinitely.

### New Design Ideas

In considering the limitations of Docker and PID 1, a new design was proposed:

1. **DEV_MODE and PROD_MODE:**
   - **DEV_MODE:** 
     - `restart` would be supported in `DEV_MODE`.
     - A `while` loop would maintain the script as PID 1 in the container, and a separate call would be used to launch Odoo. This way, Odoo can be restarted without the container shutting down, and the earlier `entrypoint.sh` script would still be applicable.
   - **PROD_MODE:**
     - In `PROD_MODE`, the original behavior is maintained, where `exec` is used to let Docker directly monitor the Odoo process without interference.
  
2. **Decision to Discontinue This Approach:**
   - However, after evaluating the complexity of these changes, I decided not to proceed with this design. The overhead of managing two modes (DEV and PROD) and maintaining the while loop for `DEV_MODE` was too complicated and not worth the effort. Therefore, I have decided to abandon this approach.

### Issues and Failure

Despite the attempt to gracefully manage the Odoo process, this design failed in practice due to the following reasons:

1. **Docker Container Termination:**
   Since the Odoo process was running as PID 1 in the Docker container, killing the Odoo process also resulted in the container stopping. This behavior is inherent to Docker, where PID 1 is the main process, and killing it results in the termination of the container.

2. **No Control Over PID 1:**
   The inability to control PID 1 within the container, without adding more complexity (e.g., using a process supervisor or custom init systems), limited the functionality of this approach.

3. **Complexity of the New Design:**
   The introduction of `DEV_MODE` and `PROD_MODE` added unnecessary complexity to the system. Switching between these modes and maintaining different behaviors proved to be a hassle, and thus, I decided to abandon the effort.

### Conclusion

While the script was able to stop and restart the Odoo process successfully, the overall design was deemed too complex and ultimately failed due to Docker’s management of PID 1. Alternative solutions such as using `supervisord`, `init` systems, or a different Docker architecture would be required to achieve the desired behavior. The new approach of having separate `DEV_MODE` and `PROD_MODE` was abandoned due to the complexity of implementation.

