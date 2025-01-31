#!/bin/bash

set -e # Exit immediately if a command exits with a non-zero status.

# Import configuration file
source ./config.sh

function verify_installation() {

    function scan_file() {

        echo "Performing a scan..."

        curl -X POST -F "file=@$TEST_FILE_PATH" localhost:5443/scan/direct 
    

    }

    function service_status() {

        echo "Checking service status..."

        curl -X GET  http://localhost:5443/health-check

        curl --head  http://localhost:5443/health-check

    }

    function service_metrics() {

        echo "Checking service metrics..."

        curl -X GET  http://localhost:5443/metrics/all

    }

    select DECISION in "Verify scanning feature" "Check API service status" "Check API service metrics" "Quit"; do
            case $DECISION in 
                "Verify scanning feature")
                    scan_file
                    ;;
                "Check API service status")
                    service_status 
                    ;;
                "Check API service metrics")
                    service_metrics
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

}

echo "Starting verification script for SCANOSS"
echo "Select options from the menu to verify different aspects of your environment"

verify_installation