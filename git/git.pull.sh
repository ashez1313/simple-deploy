#!/bin/bash

# Variables
REPO_URL="http://<git-access-token>:@<url-to-your-repo>" # Git repo URL
CLONE_DIR="/home/bitrix/tmp/autopull"  # clone directory
SYNC_DIR="/home/bitrix/www/" # sync directory
LOG_FILE="/home/bitrix/git/log_git.txt"  # Log file path

BACKUP_DIR="$CLONE_DIR/log_backup"            # Backup directory for SYNC_DIR/log
GITLAB_API_URL="https://<your-gitlab-url>"    # Gitlab API URL
PROJECT_ID="<your-project-id>"                # GitLab project ID
PRIVATE_TOKEN="<your-token-here>"             # GitLab private token

# Function to log messages
log_message() {
    local TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$TIMESTAMP] $1" | tee -a "$LOG_FILE"
}

# Function to send telegram alerts
send_telegram_alert() {
    local BOT_TOKEN="<your-telegram-bot-token-here>"
    local CHAT_ID="telegram-chat-id"
    local MESSAGE="$1"

    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d "chat_id=$CHAT_ID" \
        -d "text=$MESSAGE" \
        -d "parse_mode=Markdown" > /dev/null
}

# Function to check if the latest MR has at least one approval
check_mr_approval() {
    log_message "Checking if the latest MR has at least one approval..."

    # Fetch the latest MR
    MR_RESPONSE=$(curl -s --header "PRIVATE-TOKEN: $PRIVATE_TOKEN" "$GITLAB_API_URL/projects/$PROJECT_ID/merge_requests?state=merged&order_by=updated_at&sort=desc&per_page=1")
    MR_ID=$(echo "$MR_RESPONSE" | jq -r '.[0].iid')
    MR_TITLE=$(echo "$MR_RESPONSE" | jq -r '.[0].title')
    MR_AUTHOR=$(echo "$MR_RESPONSE" | jq -r '.[0].author.name')
    MR_URL=$(echo "$MR_RESPONSE" | jq -r '.[0].web_url')

    if [ -z "$MR_ID" ] || [ "$MR_ID" == "null" ]; then
        log_message "ERROR: No MR found. Exiting script."
	send_telegram_alert "❌ ERROR: no MR found. Exiting script."
        exit 1
    fi

    send_telegram_alert "❗ Merge Request: $MR_TITLE.	Author: $MR_AUTHOR.	[URL]($MR_URL)"

    log_message "Latest MR ID: $MR_ID"

    # Fetch MR approvals
    APPROVALS_RESPONSE=$(curl -s --header "PRIVATE-TOKEN: $PRIVATE_TOKEN" "$GITLAB_API_URL/projects/$PROJECT_ID/merge_requests/$MR_ID/approvals")
    APPROVALS_COUNT=$(echo "$APPROVALS_RESPONSE" | jq -r '.approved_by | length')

    if [ "$APPROVALS_COUNT" -ge 1 ]; then
        log_message "MR $MR_ID has $APPROVALS_COUNT approval(s). Proceeding with sync."
    else
        log_message "ERROR: MR $MR_ID has no approvals. Exiting script."
	send_telegram_alert "❌ ERROR: No approvals for MR #$MR_ID. Exiting script."
        exit 1
    fi
}

# Start logging
log_message "Starting script: Git clone and sync with log backup and MR approval check."
send_telegram_alert "❗ [PRODUCTION] DEPLOY - job started ... ❗"

# Step 1: Check if the latest MR has at least one approval
check_mr_approval

# Step 2: Clone the Git repository
log_message "Cloning repository from $REPO_URL into $CLONE_DIR..."
if git clone "$REPO_URL" "$CLONE_DIR" 2>&1 | tee -a "$LOG_FILE"; then
    log_message "Git clone successful."
else
    log_message "ERROR: Git clone failed. Exiting script."
    send_telegram_alert "❌ ERROR: Git clone failed. Exiting script."
    exit 1
fi

# Step 3: Backup SYNC_DIR/log to CLONE_DIR
log_message "Backing up $SYNC_DIR/log to $BACKUP_DIR..."
if [ -d "$SYNC_DIR/local/log" ]; then
    mkdir -p "$BACKUP_DIR"  # Create backup directory if it doesn't exist
    if rsync -avz "$SYNC_DIR/local/log/" "$BACKUP_DIR/" 2>&1 | tee -a "$LOG_FILE"; then
        log_message "Backup of $SYNC_DIR/log completed successfully."
    else
        log_message "ERROR: Backup of $SYNC_DIR/local/log failed. Exiting script."
	send_telegram_alert "❌ ERROR: Backup failed. Exiting script."
        exit 1
    fi
else
    log_message "No $SYNC_DIR/local/log folder found. Skipping backup."
fi

# Step 4: Sync the cloned folder with SYNC_DIR (excluding the log folder)
log_message "Syncing $CLONE_DIR with $SYNC_DIR (excluding log folder)..."
if rsync -avz --delete --exclude='log' "$CLONE_DIR/local/" "$SYNC_DIR/local/" 2>&1 | tee -a "$LOG_FILE"; then
    log_message "Sync completed successfully."
    # send_telegram_alert "✅ Sync completed successfully."
else
    log_message "ERROR: Sync failed. Exiting script."
    send_telegram_alert "❌ ERROR: Sync failed. Exiting script."
    exit 1
fi

# Step 5: Restore the log folder from backup
if [ -d "$BACKUP_DIR" ]; then
    log_message "Restoring $SYNC_DIR/local/log from backup..."
    if rsync -avz "$BACKUP_DIR/" "$SYNC_DIR/local/log/" 2>&1 | tee -a "$LOG_FILE"; then
        log_message "Restore of $SYNC_DIR/local/log completed successfully."
    else
        log_message "ERROR: Restore of $SYNC_DIR/log failed."
	send_telegram_alert "❌ ERROR: Restore failed."
        exit 1
    fi
else
    log_message "No backup folder found. Skipping restore."
    send_telegram_alert "❌ No backup folder found. Skipping restore.."
fi
                                    
# End logging
log_message 'Script execution completed.'
send_telegram_alert '✅ Production deploy is complete.'
