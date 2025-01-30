#!/bin/bash

function verify_installation() {

    local DECISION=$1

    scan_file {

        echo "Performing a scan.."
    

    }

    service_status {
    
    }

    service_metrics {
    
    }

    select DECISION in "" "Install application dependencies" "Engine" "ldb" "API" "Encoder" "Quit"
        do
            case $application in 
                "Install all applications and application dependencies")
                    install_application_dependencies
                    installDpkg "engine"
                    installDpkg "ldb"
                    installApi
                    installEncoderLib
                    ;;
                "Install application dependencies")
                    install_application_dependencies 
                    ;;
                "Engine")
                    installDpkg "engine"
                    ;;
                "ldb")
                    installDpkg "ldb"
                    ;;
                "API")
                    installApi
                    ;;
                "Encoder")
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