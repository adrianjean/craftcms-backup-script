#!/bin/bash
set -euo pipefail
# CraftCMS Backup Script: nxWeb Custom
# Updated: 2025-04-25
# How to use: 
# backup.sh <path to CraftCMS project> [-s | --silent] [--no-log]
# Example:
# backup-craftcms.sh /srv/www/craftcms
#
# LICENSE
# This script is released under the [Creative Commons Attribution](https://creativecommons.org/licenses/by/4.0/) license.  
# It is free to use, modify, and distribute with attribution, provided as-is and without warranty of any kind. 
# TEST ALL BACKUPS TO ENSURE THEY PROVIDE THE REDUNDANCY YOU DESIRE.
# --------------------------------------------------------------------------------------------

# Set the basePath to one of several options based on the hostname
basePath="/srv/www/"

DATE=$(date +"%Y-%m-%d-%H-%M-%S")

# Number of days to retain backup and log files
RETENTION_DAYS=14

# Directories to backup (relative to the project root)
BACKUP_DIRECTORIES=(
  "config"
  "modules"
  "templates"
  "web/css"
  "web/js"
  "translations"
)

# Default logging enabled
LOGGING_ENABLED=true

# Color variables
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"
CHECK="\xE2\x9C\x94"

# Parse arguments for --no-log and remove it from the positional parameters
args=()
for arg in "$@"; do
    if [[ "$arg" == "--no-log" ]]; then
        LOGGING_ENABLED=false
    else
        args+=("$arg")
    fi
done
set -- "${args[@]}"

# Help flag
if [[ "${1-}" == "-h" || "${1-}" == "--help" ]]; then
  echo
  echo -e "${YELLOW}CraftCMS Backup Script — Usage:${RESET}"
  echo
  echo "  ./backup.sh <project_path> [mysql_config_file] [-s|--silent] [--no-log]"
  echo
  echo "Arguments:"
  echo "  project_path         Absolute or relative path to the CraftCMS project root"
  echo "  mysql_config_file    (optional) Not used in current version, kept for compatibility"
  echo "  -s, --silent         Runs completely silently. Suppress all confirmations and prompts"
  echo "  --no-log             Disable logging to file"
  echo "  -h, --help           Show this help message and exit"
  echo
  exit 0
fi

print_header() {
    echo -e "${YELLOW}  ------------------------------------------------ ${RESET}"
    echo -e "${YELLOW}  CraftCMS Backup Script -  Started: $(date +"%Y-%m-%d (%H:%M:%S)") ${RESET}"
    echo
}

check_requirements() {
    # Check if all the needed commands are installed on the system
    required_commands=(jq curl tar mysqldump)
    for cmd in "${required_commands[@]}"; do
      if ! command -v "$cmd" &> /dev/null; then
        echo "$cmd is not installed on the system. To install $cmd run: sudo apt install $cmd. Exiting."
        exit 1
      fi
    done
}

# Reusable function that checks if the last command was successful and if not, output an error message and exit the script
check_command() {
  if [ $? -ne 0 ]; then
    echo "Backup Script Failed. Error on line: $LINENO"
    exit 1
  fi
}

setup_directories() {
    echo -e "${YELLOW}  Creating necessary backup directory structure... ${RESET}"
    # Check to see if the backups directory exists and if not create it
    if [ ! -d "$PROJECT_PATH/backups" ]; then
      mkdir -p "$PROJECT_PATH/backups"
        if [ ! -d "$PROJECT_PATH/backups" ]; then
            echo "The backups directory does not exist in the project path. Failed to create the backups directory. Exiting."
            exit 1
        fi
    fi
    # Create a sub directory in the backup directory named with the date and time of the backup
    mkdir "$PROJECT_PATH/backups/$DATE"
    mkdir "$PROJECT_PATH/backups/$DATE/files"
    mkdir "$PROJECT_PATH/backups/$DATE/db"
    # Confirm the sub directory was created successfully
    if [ ! -d "$PROJECT_PATH/backups/$DATE" ] || [ ! -d "$PROJECT_PATH/backups/$DATE/files" ] || [ ! -d "$PROJECT_PATH/backups/$DATE/db" ]; then
      echo "Failed to create sub directories needed in the backups directory. Exiting."
      exit 1
    fi
}

backup_database() {
    echo -e "${YELLOW}  Backing up database... ${RESET}"

    # Create a temporary .my.cnf file
    CNF_FILE=$(mktemp)
    chmod 600 "$CNF_FILE"
    cat > "$CNF_FILE" <<EOF
[client]
user=$CRAFT_DB_USER
password=$CRAFT_DB_PASSWORD
host=$CRAFT_DB_SERVER
port=$CRAFT_DB_PORT
EOF

    # Backup the database using the temp .my.cnf
    mysqldump --defaults-extra-file="$CNF_FILE" --single-transaction --set-gtid-purged=OFF "$CRAFT_DB_DATABASE" > "$PROJECT_PATH/backups/$DATE/db/db-$DATE.sql"

    # Check if mysqldump command was successful
    if [ $? -ne 0 ]; then
        echo "Failed to create the database backup. The mysqldump command failed. Exiting."
        rm -f "$CNF_FILE"
        exit 1
    fi

    # Securely remove the temp .my.cnf
    rm -f "$CNF_FILE"

    echo -e "${GREEN}${CHECK} - Database backup successful ${RESET}"
}

backup_project_files() {
    echo -e "${YELLOW}  Backing project files... ${RESET}"
    # Backup critical directories for the CraftCMS project
    backup_dir() {
        local dir=$1
        if [ -d "$PROJECT_PATH/$dir" ]; then
            # Create a new variable that strips any slashes from the directory name and replaces them with dashes
            dir_clean=$(echo "$dir" | sed 's/\//\-/g')
            echo -e "    ${YELLOW}  Backing up /$dir ... ${RESET}"
            tar -czf "$PROJECT_PATH/backups/$DATE/files/$dir_clean.tar.gz" --directory="$PROJECT_PATH/$dir" .
            # Check if the tar command was successful
            if [ $? -ne 0 ]; then
                echo "Failed to backup core directory for /$dir. Exiting."
                exit 1
            fi
        else 
            echo -e "    ${RED} /$dir does not exist. Skipping... ${RESET}"
        fi
    }
    for dir in "${BACKUP_DIRECTORIES[@]}"; do
      backup_dir "$dir"
    done
    echo -e "${GREEN}${CHECK} - All directory backups successful ${RESET}"

    echo -e "${YELLOW}  Backing up .env and composer.json files ${RESET}"
    cp "$PROJECT_PATH/.env" "$PROJECT_PATH/backups/$DATE/env-backup.txt"
    cp "$PROJECT_PATH/composer.json" "$PROJECT_PATH/backups/$DATE/composer.json"
    echo -e "${GREEN}${CHECK} - Done. ${RESET}"
}

finalize_backup() {
    echo -e "${YELLOW}  Compressing backup... ${RESET}"
    tar -czf "$PROJECT_PATH/backups/backup-$PROJECT_NAME-$DATE.tar.gz" --directory="$PROJECT_PATH/backups/$DATE" .
    # Check to see if the tar command was successful
    if [ $? -ne 0 ]; then
      echo "Failed to compress backup file. Exiting."
      exit 1
    fi
    echo -e "${GREEN}${CHECK} - Done. ${RESET}"

    echo -e "${YELLOW}  Checking the integrity of the backup... ${RESET}"
    tar -tzf "$PROJECT_PATH/backups/backup-$PROJECT_NAME-$DATE.tar.gz" > /dev/null
    # Check if the tar command was successful
    if [ $? -ne 0 ]; then
      echo "Failed to check the integrity of the backup file. Exiting."
      exit 1
    fi
    echo -e "${GREEN}${CHECK} - Backup passed integrity check. ${RESET}"

    echo -e "${YELLOW}  Removing working files... ${RESET}"
    rm -rf "$PROJECT_PATH/backups/$DATE"
    echo -e "${GREEN}${CHECK} - Done. ${RESET}"

    echo -e "${YELLOW}  Removing backup files older than $RETENTION_DAYS days... ${RESET}"
    find "$PROJECT_PATH/backups" -name "*.tar.gz" -type f -mtime +$RETENTION_DAYS -exec rm -f {} \;
    echo -e "${GREEN}${CHECK} - Old backup archives removed. ${RESET}"

    echo -e "${YELLOW}  Removing log files older than $RETENTION_DAYS days... ${RESET}"
    find "$PROJECT_PATH/backups/logs" -name "*.log" -type f -mtime +$RETENTION_DAYS -exec rm -f {} \;
    echo -e "${GREEN}${CHECK} - Old logs removed. ${RESET}"
    echo -e "${GREEN}${CHECK} - Local backup completed successfully. ${RESET}"

    DATE_FINISHED=$(date +"%Y-%m-%d (%H:%M:%S)")
    echo -e "${GREEN}${CHECK} - Backup filename: backup-$PROJECT_NAME-$DATE.tar.gz ${RESET}"
    echo -e "${GREEN}${CHECK} - Script finished on: $DATE_FINISHED ${RESET}"
    echo -e "${YELLOW}  ------------------------------------------------ ${RESET}"
}

# Check if the last command-line argument is -s or --silent
# if not set the silent_mode variable to false
if [ "$#" -eq 2 ] && { [ "${2-}" == "-s" ] || [ "${2-}" == "--silent" ]; }; then
  silent_mode=true
else
  silent_mode=false
fi

print_header

check_requirements

# --------------------------------------------------------------------------------------------
# Check if the first argument was a provided path.
# If not, ask the user for input supplying a default path option
if [ -z "${1-}" ]; then
  read -e -p "Enter the path to the CraftCMS project: " -i "$basePath" PROJECT_PATH
else
  if [ "${1-}" = "." ]; then
    PROJECT_PATH=$(pwd)
  else
    PROJECT_PATH="${1-}"
  fi
fi
# Show the user the path to the CraftCMS project
echo -e "${GREEN}${CHECK} - CraftCMS project path is valid: $PROJECT_PATH ${RESET}"

# Parse the project path to get the project name
PROJECT_NAME=$(basename "$PROJECT_PATH")
# Check to see is the project path is valid
if [ ! -d "$PROJECT_PATH" ]; then
  echo "Invalid path to the CraftCMS project"
  exit 1
else
    echo -e "${GREEN}${CHECK} - Project name set to: $PROJECT_NAME ${RESET}"
fi

# Setup logging if enabled
if [ "$LOGGING_ENABLED" = true ]; then
    # Ensure the logs directory exists before setting up the log file
    mkdir -p "$PROJECT_PATH/backups/logs"
    LOGFILE="$PROJECT_PATH/backups/logs/backup-$DATE.log"
    exec > >(tee -a "$LOGFILE") 2>&1
fi

# Check to see if the .env file exists
if [ ! -f "$PROJECT_PATH/.env" ]; then
  echo "The .env file does not exist in the project path, are you sure this is a CraftCMS project?"
  echo "If this is a CraftCMS project, please make sure the .env file is in the project path."
  exit 1
fi
# Print in green color
echo -e "${GREEN}${CHECK} - The .env file exists in the project path ${RESET}"
# Set a variable for the .env file
ENV_FILE="$PROJECT_PATH/.env"

# Load all variables from the ENV_FILE so we can use them in the script
set -o allexport
source "$ENV_FILE"
set +o allexport
# echo -e "\033[32m\xE2\x9C\x94 - All variables in .env loaded: \033[0m"

# --------------------------------------------------------------------------------------------
# A reusable function to check if the supplied variable is set in the .env file.
check_variable() {
    local variable_name=$1
    local value="${!variable_name}"

    if [ -z "$value" ]; then
        echo "The $variable_name variable is not set in the .env file. Exiting."
        exit 1
    fi

    if [[ "$variable_name" == *PASSWORD* ]]; then
        local length=${#value}
        if [ $length -gt 1 ]; then
            local obfuscated
            obfuscated=$(printf "%*s" $((length - 1)) "" | tr ' ' '*')${value: -4}
        else
            local obfuscated="*"
        fi
        echo -e "    ${GREEN}${CHECK} - Setting $variable_name to: $obfuscated ${RESET}"
    else
        echo -e "    ${GREEN}${CHECK} - Setting $variable_name to: $value ${RESET}"
    fi
}
# Check if all the reequired variables are set in the .env file if not exit the script
check_variable "CRAFT_DB_DATABASE"
check_variable "CRAFT_DB_SERVER"
check_variable "CRAFT_DB_PORT"
check_variable "CRAFT_DB_USER"
check_variable "CRAFT_DB_PASSWORD"
echo -e "${GREEN}${CHECK} - All required variables are set in the .env file ${RESET}"


if [ "$silent_mode" = false ]; then
    echo -e "${GREEN}${CHECK} - Good to go! ${RESET}"
    echo 
fi

# --------------------------------------------------------------------------------------------
# Ask the user if they want to continue with the backup
if [ "$silent_mode" = false ]; then
    read -p "Are you sure you want to continue with the backup? (y/n) [y]: " CONTINUE
    CONTINUE=${CONTINUE:-y}
else
    CONTINUE="y"
fi
if [ "$CONTINUE" != "y" ]; then
  echo "Backup cancelled. Exiting."
  exit 1
fi

echo 
echo -e "${YELLOW}  Backup starting... ${RESET}"

setup_directories

backup_database

backup_project_files

finalize_backup

exit 0

