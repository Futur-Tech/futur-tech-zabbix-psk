#!/usr/bin/env bash

# https://sbcode.net/zabbix/agent-psk-encryption/

# Deploy PSK Key for Zabbix Agent/Proxy v1.0

# Usage: 
# To load a specific key:   deploy.sh <agent|proxy> <psk_identity> <psk_key>
# To generate a random key: deploy.sh <agent|proxy> new-psk
# To update confs:          deploy.sh <agent|proxy>


source "$(dirname "$0")/ft-util/ft_util_inc_var"

$S_LOG -d $S_NAME "Start $S_NAME $*"

if [ "$1" = "agent" ] || [ "$1" = "proxy" ]
then
    ZBX_TYPE="$1" # "agent" or "proxy"

else
    $S_LOG -d $S_NAME "Doing nothing, you need to give at least one parameter (agent or proxy)."
    $S_LOG -d "$S_NAME" "End $S_NAME"
    exit 0
fi
$S_LOG -d "$S_NAME" "The script will run for Zabbix $ZBX_TYPE" 

#############################
#############################
## CHECK OS
#############################
#############################

if [ -d "/etc/zabbix" ]
then
    OS="Linux"
    ZBX_ETC="/etc/zabbix"
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
    NEW_PSK=1
    PSK_IDENTITY="$2"
    PSK_KEY="$3"
 
elif [[ "$2" == *"new-psk"* ]]
then
    NEW_PSK=1
    PSK_KEY="$(openssl rand -hex 32)"
    PSK_IDENTITY="ft-gen-${ZBX_TYPE}-$(hostname)"
else 
    NEW_PSK=0
fi

#############################
#############################
## SETUP SUDOER FILES (Linux only)
#############################
#############################

case $OS in
    Linux)
        SUDOERS_ETC="/etc/sudoers.d/ft-psk"

        echo 'Defaults:zabbix !requiretty' | sudo EDITOR='tee' visudo --file=$SUDOERS_ETC &>/dev/null
        echo 'zabbix ALL=(ALL) NOPASSWD:/usr/local/src/futur-tech-zabbix-psk/deploy.sh' | sudo EDITOR='tee -a' visudo --file=$SUDOERS_ETC &>/dev/null
        echo 'zabbix ALL=(ALL) NOPASSWD:/usr/local/src/futur-tech-zabbix-psk/deploy-update.sh' | sudo EDITOR='tee -a' visudo --file=$SUDOERS_ETC &>/dev/null

        cat $SUDOERS_ETC | $S_LOG -d "$S_NAME" -d "$SUDOERS_ETC" -i 
        ;;
esac


#############################
#############################
## DEPLOY KEY AND CONF
#############################
#############################

ZBX_PSK_CONF=${ZBX_ETC}/zabbix_${ZBX_TYPE}d.d/ft-psk.conf
ZBX_PSK_CONF_USERPARAM=${ZBX_ETC}/zabbix_${ZBX_TYPE}d.d/ft-psk-userparam.conf
ZBX_PSK_KEY=${PSK_FLD}/key-${ZBX_TYPE}.psk

if [ $NEW_PSK -eq 1 ]
then
    $S_LOG -d "$S_NAME" -d "Installing Zabbix PSK Key" 
    if [ ! -d "${PSK_FLD}" ]
    then
        mkdir ${PSK_FLD}/
        chown zabbix:zabbix ${PSK_FLD}
        # chmod 700 ${PSK_FLD}
    fi
    echo $PSK_KEY > ${ZBX_PSK_KEY}
    chown zabbix:zabbix ${ZBX_PSK_KEY}
    chmod 600 ${ZBX_PSK_KEY}

    $S_LOG -d "$S_NAME" -d "Installing Zabbix PSK Conf" 
    echo "TLSConnect=psk" > $ZBX_PSK_CONF
    echo "TLSAccept=psk" >> $ZBX_PSK_CONF
    echo "TLSPSKIdentity=$PSK_IDENTITY" >> $ZBX_PSK_CONF
    echo "TLSPSKFile=${ZBX_PSK_KEY}" >> $ZBX_PSK_CONF

    echo "" 
    echo "####################################################"
    echo "###################  WARNING  ######################"
    echo "####################################################"
    echo ""
    echo "Update your server-side host configuration!"
    echo "" 
    echo "PSK_IDENTITY"
    grep -oP '^TLSPSKIdentity=\K.+' ${ZBX_PSK_CONF}
    echo "" 
    echo "PSK_KEY"
    cat ${ZBX_PSK_KEY}
    echo "" 
    echo "####################################################"
    echo "###################  WARNING  ######################"
    echo "####################################################"
    echo "" 

fi

if [ "${ZBX_TYPE}" = "agent" ]
then
    $S_LOG -d "$S_NAME" -d "Installing Zabbix UserParameters" 
    echo "UserParameter=ft-psk.identity, grep -oP '^TLSPSKIdentity=\K.+' ${ZBX_PSK_CONF}" > $ZBX_PSK_CONF_USERPARAM
    echo "UserParameter=ft-psk.key.lastmodified, stat --format=%Y ${ZBX_PSK_KEY}" >> $ZBX_PSK_CONF_USERPARAM
fi

case $OS in
    Linux)
        echo "service zabbix-${ZBX_TYPE} restart" | at now + 1 min &>/dev/null ## restart zabbix ${ZBX_TYPE} with a delay
        $S_LOG -s $? -d "$S_NAME" "Scheduling Zabbix ${ZBX_TYPE} Restart"
        ;;
esac

$S_LOG -d "$S_NAME" "End $S_NAME"

exit