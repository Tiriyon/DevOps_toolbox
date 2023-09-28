#!/bin/bash

# Define the list of directories
list_to_move=($(<file_list))

# Function to get the file name from the path
get_file_name() {
    echo $(basename "$1")
}

# Function to handle renaming and logging
rename_files() {
    local new_item_name=$1
    local timestamp=$(date +"%Y%m%d:%H%M")
    
    for item_path in "${list_to_move[@]}"; do
        if [ -e "$item_path" ]; then
            item_name=$(get_file_name "$item_path")
            new_path="${item_path%/*}/$new_item_name"
            
            # Check if the new path already exists
            if [ -e "$new_path" ]; then
                echo "$timestamp: Error: $new_path already exists. Skipping $item_path" >> mass_rename_log.txt
            else
                if [ "$dry_run" == "true" ]; then
                    echo "$timestamp: Dry run - File $item_path would be changed to $new_path"
                else
                    mv "$item_path" "$new_path"
                    echo "$timestamp: File $item_path has been changed to $new_path"
                    echo "$timestamp: File $item_path has been changed to $new_path" >> mass_rename_log.txt
                fi
            fi
        else
            echo "$timestamp: Error: $item_path not found" >> mass_rename_log.txt
        fi
    done
}

# Main method
main() {
    local dry_run="false"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                dry_run="true"
                shift
                ;;
            *)
                local new_item_name="$1"
                shift
                ;;
        esac
    done
    
    # Check if a new item name is provided
    if [ -z "$new_item_name" ]; then
        echo "Usage: $0 [--dry-run] <new_item_name>"
        exit 1
    fi
    
    # Call the function to handle renaming and logging
    rename_files "$new_item_name"
}

# Call the main method with the provided arguments
main "$@"

