#!/bin/bash

# Set variables
TARGET_DIRS=("/nsm/pcap" "/nsm/zeek/logs")  # List of target directories
TARGET_QUOTAS=("30" "70")  # Quotas for each directory in percentage (must add up to 100)
BATCH_SIZE=("5" "50")  # Number of files to delete in each loop iteration for each directory
ACTION_THRESHOLD=89  # Take no action until total used space on partition exceeds this percentage
DEBUG=true  # Set to true to enable debug mode, false for normal execution

# Validate that TARGET_QUOTAS add up to 100
quota_sum=0
for quota in "${TARGET_QUOTAS[@]}"; do
    quota_sum=$((quota_sum + quota))
done

if [[ "$quota_sum" -ne 100 ]]; then
    echo "Error: TARGET_QUOTAS must add up to 100."
    exit 1
fi

# Check the total used space on the filesystem of the first target directory
partition_used=$(df --output=pcent "${TARGET_DIRS[0]}" | tail -1 | tr -d ' %')

# Exit if total used space is below the action threshold
if [[ "$partition_used" -lt "$ACTION_THRESHOLD" ]]; then
    echo "Total partition used space [$partition_used%] is below the action threshold [$ACTION_THRESHOLD%]. No action needed."
    exit 0
fi

echo "Total partition used space [$partition_used%] is above the action threshold [$ACTION_THRESHOLD%]. Starting cleanup process."

# Calculate the total space used by only the specified directories
effective_total_used=0
declare -A dir_used

for dir in "${TARGET_DIRS[@]}"; do
    usage=$(du -s "$dir" | awk '{print $1}')
    dir_used["$dir"]=$usage
    effective_total_used=$((effective_total_used + usage))
done

# Convert effective total used space from KB to TB for display
effective_total_used_tb=$(awk "BEGIN {printf \"%.2f\", $effective_total_used/1024/1024/1024}")

echo "Effective total used by target directories: $effective_total_used_tb TB"

# Function to enforce quota for each directory based on effective total used space
enforce_directory_quota() {
    local dir=$1
    local quota=$2
    local batch=$3
    local current_dir_used=${dir_used["$dir"]}
    
    # Calculate the target usage for this directory based on its quota percentage of the effective total
    local target_usage=$((effective_total_used * quota / 100))
    local target_usage_tb=$(awk "BEGIN {printf \"%.2f\", $target_usage/1024/1024/1024}")
    local current_dir_used_tb=$(awk "BEGIN {printf \"%.2f\", $current_dir_used/1024/1024/1024}")
    local current_dir_used_percent=$(awk "BEGIN {printf \"%.1f\", $current_dir_used/$effective_total_used*100}")

    echo "$dir: Current usage is $current_dir_used_percent% ($current_dir_used_tb TB) of effective total. Target usage is $quota% ($target_usage_tb TB)."

    # Check if the directory exceeds its target usage
    if [[ "$current_dir_used" -gt "$target_usage" ]]; then
        if [[ "$DEBUG" == true ]]; then
            # In debug mode, just print what would be done without executing it
            echo "[DEBUG] $dir: Would delete batches of $batch oldest files until usage is below $target_usage_tb TB ($quota%)."
        else
            # In normal mode, proceed with deletion
            while [[ "$current_dir_used" -gt "$target_usage" ]]; do
                # Find and delete the oldest files in batches
                files_to_delete=$(find "$dir" -type f -name "*" -printf "%T+ %p\n" 2>/dev/null | sort | head -n "$batch" | cut -d' ' -f2-)
                
                if [[ -z "$files_to_delete" ]]; then
                    echo "$dir: No more files to delete."
                    break
                fi

                echo "Deleting the following $batch files from $dir to reduce usage:"
                echo "$files_to_delete"

                # Delete the batch of files
                echo "$files_to_delete" | xargs rm -f

                # Recalculate current directory usage
                current_dir_used=$(du -s "$dir" | awk '{print $1}')
                current_dir_used_tb=$(awk "BEGIN {printf \"%.2f\", $current_dir_used/1024/1024/1024}")
                current_dir_used_percent=$(awk "BEGIN {printf \"%.1f\", $current_dir_used/$effective_total_used*100}")
            done
            echo "$dir: Final usage is now $current_dir_used_percent% ($current_dir_used_tb TB) of effective total."
        fi
    else
        echo "$dir: Usage is within target limits. No action needed."
    fi
}

# Enforce quotas for each target directory
for i in "${!TARGET_DIRS[@]}"; do
    enforce_directory_quota "${TARGET_DIRS[i]}" "${TARGET_QUOTAS[i]}" "${BATCH_SIZE[i]}"
done

echo "Script finished successfully."
exit 0
