```bash
#!/bin/bash

LOG_FILE="/path/to/your/logfile.log"
STATUS_FILE="/tmp/cluster_status"

# Function to log messages with timestamp
log_message() {
    TIMESTAMP=$(date '+%Y%m%d:%H:%M')
    echo "$TIMESTAMP >> [INFO] $1" | tee -a "$LOG_FILE"
}

# 1. Log Node Status Changes
log_node_status() {
    NODES_JSON=$(oc get nodes -o json)
    NODE_STATUS_OK=true

    while read -r NODE; do
        NAME=$(echo "$NODE" | jq -r '.name')
        READY_STATUS=$(echo "$NODE" | jq -r '.readyStatus')
        UNSCHEDULABLE=$(echo "$NODE" | jq -r '.unschedulable')

        NODE_STATE="Ready"
        [ "$READY_STATUS" != "True" ] && NODE_STATE="NotReady"
        [ "$UNSCHEDULABLE" = "true" ] && NODE_STATE="${NODE_STATE},SchedulingDisabled"

        if [ "$NODE_STATE" != "Ready" ]; then
            log_message "Waiting Node Ready, $NAME, Node is Ready,\"$NODE_STATE\""
            NODE_STATUS_OK=false
            NODE_ISSUES=true
        fi
    done < <(echo "$NODES_JSON" | jq -r '.items[] | 
        {
            name: .metadata.name,
            readyStatus: (.status.conditions[] | select(.type=="Ready") | .status),
            unschedulable: .spec.unschedulable
        }' | jq -c '.')

    if [ "$NODE_STATUS_OK" = "false" ]; then
        NODE_ISSUES=true
    fi
}

# 2. Log MCP Updates and Degradations
log_mcp_status() {
    MCP_JSON=$(oc get mcp -o json)
    MCP_STATUS_OK=true

    while read -r MCP; do
        NAME=$(echo "$MCP" | jq -r '.name')
        CONDITIONS=$(echo "$MCP" | jq -r '.conditions')
        MACHINE_COUNT=$(echo "$MCP" | jq -r '.machineCount')
        READY_MACHINE_COUNT=$(echo "$MCP" | jq -r '.readyMachineCount')
        UPDATED_MACHINE_COUNT=$(echo "$MCP" | jq -r '.updatedMachineCount')
        DEGRADED_MACHINE_COUNT=$(echo "$MCP" | jq -r '.degradedMachineCount')

        UPDATING=$(echo "$CONDITIONS" | jq -r '.[] | select(.type=="Updating") | .status')
        DEGRADED=$(echo "$CONDITIONS" | jq -r '.[] | select(.type=="Degraded") | .status')

        if [ "$UPDATING" = "True" ] || [ "$DEGRADED" = "True" ]; then
            if [ "$UPDATING" = "True" ]; then
                UPDATING_TEXT="is updating"
            else
                UPDATING_TEXT="is not updating"
            fi

            if [ "$DEGRADED" = "True" ]; then
                DEGRADED_TEXT="degraded"
            else
                DEGRADED_TEXT="not degraded"
            fi

            log_message "MCP: $NAME $UPDATING_TEXT, $DEGRADED_TEXT, ready machines $READY_MACHINE_COUNT/$MACHINE_COUNT, updated machines $UPDATED_MACHINE_COUNT/$MACHINE_COUNT, degraded machine $DEGRADED_MACHINE_COUNT/$MACHINE_COUNT"
            MCP_STATUS_OK=false
            MCP_ISSUES=true
        fi
    done < <(echo "$MCP_JSON" | jq -r '.items[] | 
        {
            name: .metadata.name,
            conditions: .status.conditions,
            machineCount: .status.machineCount,
            readyMachineCount: .status.readyMachineCount,
            updatedMachineCount: .status.updatedMachineCount,
            degradedMachineCount: .status.degradedMachineCount
        }' | jq -c '.')

    if [ "$MCP_STATUS_OK" = "false" ]; then
        MCP_ISSUES=true
    fi
}

# 3. Log CO Progress and Degradations
log_co_status() {
    CO_JSON=$(oc get co -o json)
    CO_STATUS_OK=true

    while read -r CO; do
        NAME=$(echo "$CO" | jq -r '.name')
        CONDITIONS=$(echo "$CO" | jq -r '.conditions')

        AVAILABLE=$(echo "$CONDITIONS" | jq -r '.[] | select(.type=="Available") | .status')
        PROGRESSING=$(echo "$CONDITIONS" | jq -r '.[] | select(.type=="Progressing") | .status')
        DEGRADED=$(echo "$CONDITIONS" | jq -r '.[] | select(.type=="Degraded") | .status')
        MESSAGE=$(echo "$CONDITIONS" | jq -r '.[] | select(.type=="Progressing" or .type=="Degraded") | .message' | head -1)

        if [ "$PROGRESSING" = "True" ] || [ "$DEGRADED" = "True" ]; then
            if [ "$AVAILABLE" = "True" ]; then
                AVAILABILITY="is available"
            else
                AVAILABILITY="is NOT available"
            fi

            STATUS_TEXT=""
            [ "$PROGRESSING" = "True" ] && STATUS_TEXT="progressing"
            if [ "$DEGRADED" = "True" ]; then
                if [ -n "$STATUS_TEXT" ]; then
                    STATUS_TEXT="$STATUS_TEXT and DEGRADED"
                else
                    STATUS_TEXT="DEGRADED"
                fi
            fi

            log_message "CO $NAME $AVAILABILITY and $STATUS_TEXT, reason: $MESSAGE"
            CO_STATUS_OK=false
            CO_ISSUES=true
        fi
    done < <(echo "$CO_JSON" | jq -r '.items[] | 
        {
            name: .metadata.name,
            conditions: .status.conditions
        }' | jq -c '.')

    if [ "$CO_STATUS_OK" = "false" ]; then
        CO_ISSUES=true
    fi
}


main() {
    # Read the previous status and timestamp at the start of each run
    if [ -f "$STATUS_FILE" ]; then
        PREV_STATUS=$(grep 'STATUS=' "$STATUS_FILE" | cut -d'=' -f2)
        PREV_TIMESTAMP=$(grep 'TIMESTAMP=' "$STATUS_FILE" | cut -d'=' -f2)
    else
        PREV_STATUS="UNKNOWN"
        PREV_TIMESTAMP=$(date '+%s')
    fi

    # Assume current STATUS from previous or default to OK if unknown
    if [ "$PREV_STATUS" = "UNKNOWN" ]; then
        STATUS="OK"
    else
        STATUS="$PREV_STATUS"
    fi

    # Initially assume no issues
    NODE_ISSUES=false
    MCP_ISSUES=false
    CO_ISSUES=false

    # Run checks
    log_node_status
    log_mcp_status
    log_co_status

    # Determine STATUS based on whether issues were found
    if [ "$NODE_ISSUES" = "false" ] && [ "$MCP_ISSUES" = "false" ] && [ "$CO_ISSUES" = "false" ]; then
        STATUS="OK"
    else
        STATUS="NOT_OK"
    fi

    CURRENT_TIMESTAMP=$(date '+%s')

    # Compare STATUS to PREV_STATUS
    if [ "$STATUS" != "$PREV_STATUS" ]; then
        # Status changed
        if [ "$STATUS" = "OK" ]; then
            log_message "All Conditions Satisfied starting from $(date '+%Y%m%d:%H:%M')"
        else
            log_message "Conditions Not Satisfied starting from $(date '+%Y%m%d:%H:%M')"
        fi
        echo "STATUS=$STATUS" > "$STATUS_FILE"
        echo "TIMESTAMP=$CURRENT_TIMESTAMP" >> "$STATUS_FILE"
    else
        # Status unchanged, calculate duration
        DURATION=$((CURRENT_TIMESTAMP - PREV_TIMESTAMP))
        HOURS=$((DURATION / 3600))
        MINUTES=$(((DURATION % 3600) / 60))
        SECONDS=$((DURATION % 60))
        if [ "$STATUS" = "OK" ]; then
            log_message "All Conditions Satisfied for ${HOURS}h ${MINUTES}m ${SECONDS}s"
        else
            log_message "Conditions Not Satisfied for ${HOURS}h ${MINUTES}m ${SECONDS}s"
        fi
        # No update to STATUS_FILE since status hasn't changed
    fi
}

# Run the script continuously every 5 seconds (adjust as needed)
while true; do
    main
    sleep 5
done