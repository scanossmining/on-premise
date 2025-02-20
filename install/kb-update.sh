#!/bin/bash

set -e

source ./config.sh

KB_VERSION="latest" # KB UPDATE VERSION, latest or else (24.q1)
UPDATE_DOWNLOAD="" # LOCAL DIRECTORY TO DOWNLOAD UPDATE FOLDER TO
BASE_REMOTE_PATH="" # e.g. /ldb/customer/updates
UPDATE_FREQUENCY="" # daily, monthly, quarterly
FULL_REMOTE_PATH="" # BASE_REMOTE_PATH + UPDATE_FREQUENCY + KB_VERSION
KB_LOCATION="$LDB_LOCATION" # LOCATION OF THE LDB, MIGHT BE CUSTOM SO GIVE THE OPPORTUNITY TO OVERRIDE DEFAULT FROM config.sh


function kb_update() {

    echo "Checking for free disk space on $UPDATE_DOWNLOAD"
    log "Checking for free disk space on $UPDATE_DOWNLOAD"

    REMOTE_SIZE=$(echo "ls $BASE_REMOTE_PATH/$UPDATE_FREQUENCY/" | lftp -u "$(cat ~/.ssh_user)":"$(cat ~/.sshpass)" sftp://sftp.scanoss.com:49322 | awk -v version="$KB_VERSION" '/^[dl]/ && $9 ~ version {print 120*1024*1024*1024}')

    LOCAL_SIZE=$(df -B1 "$UPDATE_DOWNLOAD" | awk 'NR==2 {print $4}')

    if ((LOCAL_SIZE >= REMOTE_SIZE)); then
        while true; do
            read -p "Do you want to proceed with the download? (y/n) " yn
            case $yn in
                [Yy]* )
                    echo "Downloading Knowledge base update..."
                    log "Downloading Knowledge base update..."
                    lftp -u "$(cat ~/.ssh_user)":"$(cat ~/.sshpass)" -e "mirror -c -e -P 10  $FULL_REMOTE_PATH $UPDATE_DOWNLOAD; exit" sftp://sftp.scanoss.com:49322
                    ;;
                [Nn]* ) 
                    echo "Skipping knowledge base update download..."
                    ;;
                * ) 
                    echo "Please answer yes (y) or no (n).";;
            esac
        done 
    elif ((LOCAL_SIZE <= REMOTE_SIZE )); then
        echo "Disk space insufficient on $LOCAL_SIZE"
        log "Disk space insufficient on $LOCAL_SIZE"
        echo "Exiting script..."
        exit 1
    fi
        
    echo "KB Update downloaded to $UPDATE_DOWNLOAD/$KB_VERSION"
    log "KB Update downloaded to $UPDATE_DOWNLOAD/$KB_VERSION"

    while true; do
            read -p "Do you wish to proceed with the update import? (y/n) " yn
            case $yn in
                [Yy]* )

                    read -p "Enter the directory where to import the update (default: $KB_LOCATION): " KB_LOCATION_INPUT
                    KB_LOCATION=${KB_LOCATION_INPUT:-$KB_LOCATION}

                    echo "Checking for free disk space on $KB_LOCATION"

                    UPDATE_SIZE=$(du -sb "$UPDATE_DOWNLOAD/$KB_VERSION" | awk '{print $1}')
                    LDB_DISK_SPACE=$(df -sb "$LDB_LOCATION" | awk '{print $1}')
                    
                    if ((LDB_DISK_SPACE >= UPDATE_SIZE )) ; then

                    echo "Importing $UPDATE_DOWNLOAD/$KB_VERSION to $KB_LOCATION..."
                    log "Importing $UPDATE_DOWNLOAD/$KB_VERSION to $KB_LOCATION..."

                    echo "bulk insert oss from $UPDATE_DOWNLOAD/$KB_VERSION/mined WITH (THREADS=6,TMP=/data/scanoss_tmp,FILE_DEL=0)" | ldb

                    else
                        echo "Disk space insufficient on $LDB_DISK_SPACE"
                        log "Disk space insufficient on $LDB_DISK_SPACE"
                        echo "Exiting script..."
                        exit 1
                    fi
                    
                    ;;
                [Nn]* ) 
                    echo "Exiting knowledge base setup..."
                    exit 0
                    ;;
                * ) 
                    echo "Please answer yes (y) or no (n).";;
            esac
    done

}

echo "Starting knowledge base update script..."
log "Starting knowledge base update script..."


if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root."
  exit 1
fi

read -p "Enter the provided remote knowledge base path: " BASE_REMOTE_PATH

while true; do
            read -p "Enter the knowledge base version date (daily/monthly/quarterly): " UPDATE_FREQUENCY
            UPDATE_FREQUENCY=$(echo "$UPDATE_FREQUENCY" | tr '[:upper:]' '[:lower:]')
            case $UPDATE_FREQUENCY in
                daily)
                    UPDATE_FREQUENCY="daily"
                    break
                    ;;
                monthly) 
                    UPDATE_FREQUENCY="monthly"
                    break
                    ;;
                quarterly)
                    UPDATE_FREQUENCY="quarterly"
                    break
                    ;;
                * ) 
                    echo "Please answer a valid option (daily/monthly/quarterly).";;
            esac
done

echo "Available versions: "
echo "-------------------"

echo "ls $BASE_REMOTE_PATH/$UPDATE_FREQUENCY" | lftp -u "$(cat ~/.ssh_user)":"$(cat ~/.sshpass)" sftp://sftp.scanoss.com:49322 | awk '/^[dl]/ {printf "%.1fGB\t%s\n", 120, $9}'

echo "-------------------"
echo 

read -p "Enter the knowledge base version (default: latest): " KB_VERSION_INPUT
KB_VERSION=${KB_VERSION_INPUT:-$KB_VERSION}

FULL_REMOTE_PATH="$BASE_REMOTE_PATH/$UPDATE_FREQUENCY/$KB_VERSION"

read -p "Enter the download directory location (directories will be created if they don't exist): " UPDATE_DOWNLOAD

mkdir -p "$UPDATE_DOWNLOAD"

while true; do
    echo
    echo "Knowledge Base Update Menu"
    echo "------------------------"
    echo "1) Start knowledge base update"
    echo "2) Quit"
    echo
    read -p "Enter your choice [1-2]: " choice

    case $choice in
        1)
            kb_update
            ;;
        2)
            echo "Exiting script..."
            exit 0
            ;;
        *)
            echo "Invalid option. Please enter a number between 1-4."
            ;;
    esac
done
