#!/bin/bash

set -e # Exit immediately if a command exits with a non-zero status.

# Import configuration file
source ./config.sh

function download_kb () {

  # Add commands to install application here
  read -p "Download SCANOSS KB (y/abort) [abort]? " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]] ; then
    echo "Preparing download..."
  else
    echo "Stopping."
    exit 1
  fi

  # Confirm LDB download directory
  read -p "Enter the directory where to download the KB (default: $LDB_LOCATION): " DOWNLOAD_LOCATION
  DOWNLOAD_LOCATION=${DOWNLOAD_LOCATION:-$LDB_LOCATION}

  log "Downloading $REMOTE_LDB_LOCATION KB to $DOWNLOAD_LOCATION..."

  lftp -u "$(cat ~/.ssh_user)":"$(cat ~/.sshpass)" -e "mirror -c -e -P 10  $REMOTE_LDB_LOCATION $DOWNLOAD_LOCATION/oss; exit" sftp://sftp.scanoss.com:49322
  
  echo "SCANOSS KB installation successful!"

  read -p "Configure SCANOSS KB permissions and directories on this server (yes/no): " END_USER
  END_USER_LOWER=$(echo "$END_USER" | tr '[:upper:]' '[:lower:]') 
    
  case "$END_USER" in 
    "yes")
      # Create symlink if necesary
      if [[ "$DOWNLOAD_LOCATION" != "$LDB_LOCATION" ]]; then
        log "Creating symlink to $DOWNLOAD_LOCATION"
        echo "Download directory is not the ldb default $LDB_LOCATION. Creating symlink to $DOWNLOAD_LOCATION..."
        ln -s $DOWNLOAD_LOCATION/oss $LDB_LOCATION/oss
      fi

      # At last, update permissions
      chown -R $RUNTIME_USER:$RUNTIME_USER $DOWNLOAD_LOCATION

      echo "Configuration finished!"
    ;;
    "no")
    echo "Skipping SCANOSS KB configuration..."
    ;;
  esac

}
# Main script
echo "Starting knowledge base installation script..."

# Make sure we're running as root
if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root."
  exit 1
fi

# Confirm if LDB folder exists. Create it otherwise.
if [ ! -d $LDB_LOCATION ]; then
  mkdir -p $LDB_LOCATION
fi

# Check for free space in LDB directory
freespace=$(df --output=avail -B1T $LDB_LOCATION | awk 'NR==2 {print $1}')
if awk -v freespace="$freespace" -v FREE_SPACE_REQUIRED="$FREE_SPACE_REQUIRED" 'BEGIN { if (freespace > FREE_SPACE_REQUIRED) exit 0; else exit 1 }'; then
  echo "Free space is over $FREE_SPACE_REQUIRED TB"
else
  echo "Free space is not over $FREE_SPACE_REQUIRED TB"
  exit 1
fi

while true; do
    echo
    echo "SCANOSS KB Installation Menu"
    echo "------------------------"
    echo "1) Install SCANOSS KB "
    echo "2) Quit"
    read -p "Enter your choice [1-2]: " kb_choice

    case $kb_choice in
        1)
            download_kb
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
