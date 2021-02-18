#!/usr/bin/env bash

# https://sbcode.net/zabbix/agent-psk-encryption/

# Deploy PSK Key for Zabbix Agent/Proxy v1.0

# Usage: deploy.sh <agent|proxy> <psk_identity> <psk_key>
# If no <psk_identity> or <psk_key>, both will be automatically generated

source "$(dirname "$0")/ft-util/ft-util_inc_var"

$S_LOG -d $S_NAME "Start $S_NAME $*"


if [ "$1" = "agent" ] or [ "$1" = "proxy" ]
then
    $ZBX_TYPE="$1" # "agent" or "proxy"
else
    $S_LOG -d $S_NAME "Doing nothing, you need to give at least one parameter (agent or proxy)."
    exit 0
fi
$S_LOG -d "$S_NAME" "The script will run for Zabbix $ZBX_TYPE" 

#############################
#############################
## CHECK OS
#############################
#############################

if [ -d "/etc/zabbix/" ]
then
    OS="Linux"
    ZBX_ETC="/etc/zabbix/"
    PSK_FLD="/home/zabbix"
    
elif [ -d "/usr/local/zabbix/etc/" ]
then
    OS="Synology"

else
    $S_LOG -s crit -d $S_NAME "Sorry Zabbix conf folder could not be found. Exit."
    exit 1
fi
$S_LOG -d "$S_NAME" "The script will run for $OS" 


#############################
#############################
## LOAD PARAMETERS
#############################
#############################

if [ -n "$2" ] && [ -n "$3" ]
then 
    PSK_IDENTITY="$2"
    PSK_KEY="$3"
else
    PSK_KEY="$(openssl rand -hex 32)"
    PSK_IDENTITY="ft-gen-${ZBX_TYPE}-$(hostname)"
fi


#############################
#############################
## SETUP SUDOER FILES (Linux only)
#############################
#############################

case $OS in
    Linux)
        SUDOERS_ETC="/etc/sudoers.d/ft-psk"

        echo 'Defaults:zabbix !requiretty' | sudo EDITOR='tee' visudo $SUDOERS_ETC &>/dev/null
        echo 'zabbix ALL=(ALL) NOPASSWD:/usr/local/src/futur-tech-zabbix-psk/deploy-update.sh' | sudo EDITOR='tee -a' visudo $SUDOERS_ETC &>/dev/null

        cat $SUDOERS_ETC | $S_LOG -d "$S_NAME" -d "$SUDOERS_ETC" -i 
        ;;
esac


#############################
#############################
## DEPLOY KEY AND CONF
#############################
#############################

mkdir ${PSK_FLD}/
chown zabbix:zabbix ${PSK_FLD}
# chmod 700 ${PSK_FLD}


echo $PSK_KEY > ${PSK_FLD}/key.psk
chown zabbix:zabbix ${PSK_FLD}/key.psk
chmod 600 ${PSK_FLD}/secret.psk

ZBX_PSK_CONF=${ZBX_ETC}/zabbix_${ZBX_TYPE}d.d/ft-psk.conf

$S_LOG -d "$S_NAME" -d "Installing new PSK" 
echo "TLSConnect=psk" > $ZBX_PSK_CONF
echo "TLSAccept=psk" >> $ZBX_PSK_CONF
echo "TLSPSKFile=${PSK_FLD}/key.psk" >> $ZBX_PSK_CONF
echo "TLSPSKIdentity=$PSK_IDENTITY" >> $ZBX_PSK_CONF
echo "UserParameter=ft-psk.identity, grep TLSPSKIdentity= ${ZBX_PSK_CONF}" >> $ZBX_PSK_CONF

$S_LOG -d "$S_NAME" -d "New PSK installed."

echo "####################################################"
echo "####################################################"
echo "####################################################"
echo "Update your server-side host configuration!"
echo "PSK_IDENTITY="
echo $PSK_IDENTITY
echo "PSK_KEY="
echo $PSK_KEY
echo "####################################################"
echo "####################################################"
echo "####################################################"


case $OS in
        Linux)
        echo "systemctl restart zabbix-agent.service" | at now + 1 min &>/dev/null ## restart zabbix agent with a delay
        $S_LOG -s $? -d "$S_NAME" "Scheduling Zabbix Agent Restart"
        ;;
esac

$S_LOG -d "$S_NAME" "End $S_NAME"

exit