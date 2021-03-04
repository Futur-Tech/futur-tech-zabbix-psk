# Zabbix - Script for generating and installing PSK key
Script Linux and DSM Synology to generate and configure PSK key on agent

## Install

    git clone https://github.com/Futur-Tech/futur-tech-zabbix-psk
    cd futur-tech-zabbix-psk

To load a specific key:
    
    sudo ./deploy.sh <agent|proxy> <psk_identity> <psk_key>

To generate a random key: 
    
    sudo ./deploy.sh <agent|proxy> new-psk
    
To update configuration only:
    
    sudo ./deploy.sh <agent|proxy>

## deploy-update.sh
  
    ./deploy-update.sh -b main
    
This script will automatically pull the latest version of the branch ("main" in the example) and relaunch itself if a new version is found. Then it will run deploy.sh. Also note that any additional arguments given to this script will be passed to the deploy.sh script.

## Credit

https://sbcode.net/zabbix/agent-psk-encryption/ for the guidelines
