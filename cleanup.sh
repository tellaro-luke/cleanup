#!/bin/bash

# Set variables
TARGET_DIR="/nsm/zeek/logs"
THRESHOLD_USED=89  # Desired maximum used space percentage
ACTION_THRESHOLD=91  # Start deleting files if used space rises above this percentage
BATCH_SIZE=50 # Number of files to delete in each loop iteration

# Check current used space on target directory
current_used=$(df --output=pcent $TARGET_DIR | tail -1 | tr -d ' %')

# Start deleting oldest files if used space is above the action threshold
if [[ "$current_used" -gt "$ACTION_THRESHOLD" ]]; then
    echo "$TARGET_DIR: Used space [$current_used%] is above action threashold [$ACTION_THRESHOLD%]. Starting to delete files."
    while [[ "$current_used" -gt "$THRESHOLD_USED" ]]; do
        # Find and delete the oldest BATCH_SIZE .log.gz files
        files_to_delete=$(find "$TARGET_DIR" -type f -name "*.log.gz" -printf "%T+ %p\n" | sort | head -n "$BATCH_SIZE" | cut -d' ' -f2-)

        if [[ -z "$files_to_delete" ]]; then
            echo "$TARGET_DIR: No more files to delete."
            exit 1
        fi

        echo "$TARGET_DIR: Deleting the following $BATCH_SIZE files to free up space:"
        echo "$files_to_delete"

        # Delete the batch of files
        echo "$files_to_delete" | xargs rm -f

        # Recalculate used space
        current_used=$(df --output=pcent $TARGET_DIR | tail -1 | tr -d ' %')
    done
else
    echo "$TARGET_DIR: Used space [$current_used%] is below action threashold [$ACTION_THRESHOLD%]. No action needed."
    exit 0
fi

echo "Script finished successfully. Used space for $TARGET_DIR is now at $current_used%."
exit 0
