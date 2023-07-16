```
#!/bin/bash

# Get list of pods
pods=$(oc get po -A | grep Terminating)

# Set the IFS to newline
IFS=$'\n'

# Iterate over each pod line
for line in $pods; do
    pod_name=$(echo "$line" | awk '{print $2}')
    namespace=$(echo "$line" | awk '{print $1}')

    # Confirm force delete
    clear
    read -n 1 -p "Are you sure you want to force delete pod '$pod_name' in namespace '$namespace'? (y/n): " confirm
    echo

    if [[ $confirm == "y" || $confirm == "Y" ]]; then
        oc delete pod "$pod_name" -n "$namespace" --force --grace-period=0
        status=$(oc get po "$pod_name" -n "$namespace" --no-headers 2>/dev/null)
        if [[ -z $status ]]; then
            echo "Pod '$pod_name' in namespace '$namespace' has been successfully deleted."
        else
            echo "Failed to delete pod '$pod_name' in namespace '$namespace'."
        fi
    else
        echo "Skipping pod '$pod_name' in namespace '$namespace'."
    fi
    echo
done
