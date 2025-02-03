#!/bin/bash

set -e # Exit immediately if a command exits with a non-zero status.

# Import configuration file
source ./config.sh

function detect_os_type() {
    if [ -f /etc/debian_version ]; then
        echo "Debian"
    elif [ -f /etc/redhat-release ] || [ -f /etc/centos-release ]; then
        echo "CentOS"
    else
        echo "This operating system is not supported, refer to the document provided with this script for more details (page X)"
        exit 1
    fi
}

function install_dependencies {
  log "Installing system dependencies..."
  
  # Define the list of dependencies to install
  packages=(
      gzip
      tar
      unzip
      ruby
      curl
      lftp
      jq
      wget
      sshpass
  ) 

  deb_packages=(
      coreutils
      unrar-free
      xz-utils
      p7zip-full
      libsodium23
  )

  rpm_packages=(
      coreutils-common
      xz
      openssh-clients
  )

  case "$OS" in
    "Debian")
        echo "Installing Debian dependencies."

        # Install the packages
        echo "Installing packages..."
        apt update && apt install -y "${packages[@]}" "${deb_packages[@]}"
        ;;
    "CentOS")
        echo "Installing CentOS dependencies."
        
        # Install dependencies
        yum update -y 
        dnf install -y openssl

        # Install the packages
        echo "Installing packages..."
        yum install -y "${packages[@]}" "${rpm_packages[@]}"

        # Install Libsodium
        yum groupinstall 'Development Tools' -y

        # Build Libsodium
        curl -O https://download.libsodium.org/libsodium/releases/libsodium-1.0.18-stable.tar.gz
        tar -xzvf libsodium-1.0.18-stable.tar.gz
        cd libsodium-stable
        ./configure
        make && make check
        make install
        ;;
    esac
}

function setup_sftp {
  # Ask for SFTP credentials
  echo "Please enter your SFTP Credentials below"
  read -p "Enter your username: " SCANOSS_SFTP_USER
  read -s -p "Enter your password: " SCANOSS_SFTP_PASSWORD
  echo ""

  if [[ -z "$SCANOSS_SFTP_USER" || -z "$SCANOSS_SFTP_PASSWORD" ]]; then
    echo "Error: username or password is empty."
    exit 1
  fi

  echo SCANOSS_LOGIN="${SCANOSS_SFTP_USER}:${SCANOSS_SFTP_PASSWORD}" > ~/.scanoss_login
  chmod 600 ~/.scanoss_login
  
  echo "$SCANOSS_SFTP_USER" > ~/.ssh_user
  chmod 600 ~/.ssh_user

  echo "$SCANOSS_SFTP_PASSWORD" > ~/.sshpass
  chmod 600 ~/.sshpass

  echo "ls" | sshpass -f ~/.sshpass sftp -o "StrictHostKeyChecking=no" -P 49322  "$SCANOSS_SFTP_USER"@sftp.scanoss.com 

  echo "Connection succesful!"

}

function download_application {
  log "Downloading Application to $APP_DIR..."
  # Add commands to install application here
  read -p "Download SCANOSS Application files (y/abort) [abort]? " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]] ; then
    echo "Setting up application download..."
  else
    echo "Stopping."
    exit 1
  fi

  read -p "Enter the installation directory location (default: $APP_DIR): " DOWNLOAD_LOCATION
  APP_DIR=${DOWNLOAD_LOCATION:-$APP_DIR}

  echo "Select the source for the installation of SCANOSS Application files:"

  select download_source in "SCANOSS (LFTP)" "Other"
  do
    case $download_source in 
        "SCANOSS (LFTP)")

            lftp -u "$(cat ~/.ssh_user)":"$(cat ~/.sshpass)" -e "mirror -c -e -P 10  /binaries/ $APP_DIR; exit" sftp://sftp.scanoss.com:49322

            break
    ;;
        "Other")

            echo "Refer to the document provided with this script (section X)"
        
            break
    ;;

    esac
  done
}

function install_application {
  log "Installing $APP_NAME to $APP_DIR..."
  # Add commands to install application here

  install_application_dependencies() {
        log "Installing application dependencies"

        local dependency_package_path="$APP_DIR/app_dependencies/"
        if [ $OS = "Debian" ]; then
            if dpkg -l | grep -q "libssl1.1"; then
                log "libssl1.1 is already installed"
            else
                dpkg -i "$dependency_package_path/debian/libssl1.1"*"amd64.deb"
            fi
        elif [ $OS = "CentOS" ]; then
            if dnf list installed | grep -q "libsodium"; then
                log "libsodium is already installed via package manager"
            else
                tar -xzvf "$dependency_package_path/centos/libsodium"*"tar.gz"
                cd "$dependency_package_path/centos/libsodium-stable"
                ./configure
                make && make check
                make install
                dnf -y install "$APP_DIR/dependencies/libsodium/"* 
            fi
        fi
        
        log "Finished installing dependencies"

        echo "Finished installing dependencies"
    
    }

  installDpkg() {
      local component=$1

      ret=$?
      if [ $ret -ne 0 ] ; then
          echo "Failed to find an installation package for $component in $APP_DIR"
          return 1
      fi

      log "Installing SCANOSS $component"

      # Special case, the engine package is called 'scanoss'
      local package_path="$APP_DIR/$component/$VERSION/$component_*_amd64.deb"
      if [ $component = "engine" ]; then
          package_path="$APP_DIR/$component/$VERSION/scanoss_*_amd64.deb"
      fi
      echo $package_path

      dpkg -i $package_path
  }

  installRpm() {
      local component=$1

      ret=$?
      if [ $ret -ne 0 ] ; then
          echo "Failed to find an installation package for $component in $APP_DIR"
          return 1
      fi

      log "Installing SCANOSS $component"

      # Special case, the engine package is called 'scanoss'
      local package_path="$APP_DIR/$component/$VERSION/scanoss*.rpm"
      if [ $component = "engine" ]; then
          package_path="$APP_DIR/$component/$VERSION/scanoss*.rpm"
      fi
      echo $package_path
      
      dnf -y install "$package_path"
  }

  # Install API

  installApi(){

    local tar_file_path="$APP_DIR/api/$VERSION/scanoss-go_linux-amd64_*.tgz"

    echo 'Extracting ' $tar_file_path
    mkdir -p $APP_DIR/tmp
    tar -xzvf $tar_file_path -C "$APP_DIR/tmp/"

    log "Installing SCANOSS API"
    
    chmod +x $APP_DIR/tmp/scripts/env-setup.sh
    (cd $APP_DIR/tmp/scripts ; ./env-setup.sh )

  }

  installEncoderLib() {

    log 'Installing SCANOSS Encoder Library'
    # Find the tar.gz file in the version directory
    local tar_file=$(find "$APP_DIR/scanoss-encoder/$VERSION" -maxdepth 1 -name "*.tar.gz" | head -n 1)
    
    if [ -n "$tar_file" ]; then
        log "Found tar.gz file: $tar_file. Extracting..."
        tar -xzf "$tar_file" -C "$APP_DIR/scanoss-encoder/$VERSION"
    else
        log "No tar.gz file found."
    fi
    
    # Copy the library file to the appropriate location
    if [ -f "$APP_DIR/scanoss-encoder/$VERSION/libscanoss_encoder.so" ]; then
        cp "$APP_DIR/scanoss-encoder/$VERSION/libscanoss_encoder.so" /usr/lib/libscanoss_encoder.so
        ldconfig
        echo "scanoss-encoder installed succesfully!"
    else
        log "Library file libscanoss_encoder.so not found."
        echo "libscanoss_encoder.so not found."
    fi
  }

  case "$OS" in
    "Debian")
    select application in "Install all applications and dependencies" "Install dependencies" "engine" "ldb" "API" "encoder" "Quit"
        do
            case $application in 
                "Install all applications and dependencies")
                    install_application_dependencies
                    installDpkg "engine"
                    installDpkg "ldb"
                    installApi
                    installEncoderLib
                    ;;
                "Install dependencies")
                    install_application_dependencies 
                    ;;
                "engine")
                    installDpkg "engine"
                    ;;
                "ldb")
                    installDpkg "ldb"
                    ;;
                "API")
                    installApi
                    ;;
                "scanoss-encoder")
                    installEncoderLib
                    ;;
                "Quit")
                    echo "Exiting..."
                    break
                    ;;
                *)
                    echo "Invalid option"
                    ;;
            esac
        done
    ;;
    "CentOS")
      select application in "Install all applications and dependencies" "Install dependencies" "engine" "ldb" "API" "scanoss-encoder" "Quit"
        do
            case $application in 
                "Install all applications and application dependencies")
                    install_application_dependencies
                    installRpm "engine"
                    installRpm "ldb"
                    installApi
                    installEncoderLib
                    ;;
                "Install dependencies")
                    install_application_dependencies 
                    ;;
                "engine")
                    installRpm "engine"
                    ;;
                "ldb")
                    installRpm "ldb"
                    ;;
                "API")
                    installApi
                    ;;
                "scanoss-encoder")
                    installEncoderLib
                    ;;
                "Quit")
                    echo "Exiting..."
                    break
                    ;;
                *)
                    echo "Invalid option"
                    ;;
            esac
        done
      ;;
    esac

}

function create_scanoss_user {

    # Makes sure the scanoss user exists
    if ! getent passwd $RUNTIME_USER > /dev/null ; then
    echo "Runtime user does not exist: $RUNTIME_USER"
    read -p "Do you want to create the user $RUNTIME_USER (y/abort) [abort]? " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] ; then
        case "$OS" in
            "Debian")
            useradd --system $RUNTIME_USER
            ;;
            "CentOS")
            adduser --system $RUNTIME_USER
            ;;
            esac
        
        echo "User $RUNTIME_USER created successfully"
    else
        echo "Stopping."
        exit 1
    fi
fi
}

# Main script
echo "Starting $APP_NAME installation script..."
log "Starting $APP_NAME installation script..."

# Make sure we're running as root
if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root."
  exit 1
fi

# Make sure the application directory exists, otherwise it creates it
if [ ! -d "$APP_DIR" ]; then
    echo "Creating application directory: $APP_DIR"
    mkdir -p "$APP_DIR"
fi

# Detect operating system automatically
OS=$(detect_os_type)

while true; do
    echo
    echo "SCANOSS Installation Menu"
    echo "------------------------"
    echo "1) Install SCANOSS Platform"
    echo "2) Install Dependencies"
    echo "3) Setup SFTP Credentials"
    echo "4) Download Application"
    echo "5) Install Application"
    echo "6) Quit"
    echo
    read -p "Enter your choice [1-6]: " choice

    case $choice in
        1)
            create_scanoss_user
            install_dependencies
            setup_sftp
            download_application
            install_application
            ;;
        2)
            install_dependencies
            ;;    
        3)
            setup_sftp
            ;;
        4)
            download_application
            ;;
        5)
            create_scanoss_user
            install_application
            ;;
        6)
            echo "Exiting script..."
            exit 0
            ;;
        *)
            echo "Invalid option. Please enter a number between 1-4."
            ;;
    esac
done
