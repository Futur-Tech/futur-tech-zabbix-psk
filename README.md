# Zabbix - Script for generating and installing PSK key
Script Linux and DSM Synology to generate and configure PSK key on agent

## Install

    git clone https://github.com/GuillaumeHullin/futur-tech-zabbix-psk
    cd futur-tech-zabbix-psk

To load a specific key:
    
    ./deploy.sh <agent|proxy> <psk_identity> <psk_key>

To generate a random key: 
    
    ./deploy.sh <agent|proxy> new-psk
    
To update configuration only:
    
    ./deploy.sh <agent|proxy>


## Credit

https://sbcode.net/zabbix/agent-psk-encryption/ for the guidelines
