#!/bin/bash

function verify_installation() {

    local DECISION=$1

    scan_file {

        echo "Performing a scan.."
    

    }

    service_status {

        echo "Checking service status.."

    }

    service_metrics {

        echo "Checking service metrics.."

    }

    select DECISION in "Verify scanning feature" "Check API service status" "Check API service metrics" "Quit"
        do
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