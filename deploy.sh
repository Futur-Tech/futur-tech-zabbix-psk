#!/usr/bin/env bash

# https://sbcode.net/zabbix/agent-psk-encryption/

# Deploy PSK Key for Zabbix Agent/Proxy v1.0

# Usage:
# To load a specific key:   deploy.sh <agent|proxy> <psk_identity> <psk_key>
# To generate a random key: deploy.sh <agent|proxy> new-psk
# To update confs:          deploy.sh <agent|proxy>

source "$(dirname "$0")/ft-util/ft_util_inc_var"

if [ "$1" = "agent" ] || [ "$1" = "proxy" ]; then
    zbx_type="$1" # "agent" or "proxy"

elif [ -z "$1" ]; then
    zbx_type="agent" # Default if empty

else
    $S_LOG -s crit -d $S_NAME "Invalid parameter, first parameter should be: \"agent\" or \"proxy\"."
    exit 0
fi
$S_LOG -d "$S_NAME" "The script will run for Zabbix $zbx_type"

# CHECKING ZABBIX PATH
psk_fld="/home/zabbix"
if [ "$zbx_type" = "agent" ]; then
    $(which zabbix_agent2 >/dev/null) && zbx_conf_d="/etc/zabbix/zabbix_agent2.d"
    $(which zabbix_agentd >/dev/null) && zbx_conf_d="/etc/zabbix/zabbix_agentd.conf.d"

elif [ "$zbx_type" = "proxy" ]; then
    zbx_conf_d="/etc/zabbix/zabbix_proxy.conf.d"
fi

if [ ! -d "${zbx_conf_d}" ]; then
    $S_LOG -s crit -d $S_NAME "${zbx_conf_d} Zabbix ${zbx_type} Include directory not found"
    exit 10
fi

zbx_psk_conf=${zbx_conf_d}/ft-psk.conf
zbx_psk_conf_userparam=${zbx_conf_d}/ft-psk-userparam.conf
zbx_psk_key=${psk_fld}/key-${zbx_type}.psk

# LOAD PARAMETERS
if [ -n "$2" ] && [ -n "$3" ]; then
    new_psk=1
    psk_identity="$2"
    psk_key="$3"

elif [[ "$2" == *"new-psk"* ]]; then
    new_psk=1
    psk_key="$(openssl rand -hex 32)"
    psk_identity="ft-gen-${zbx_type}-$(hostname)"

else
    new_psk=0
fi

#  SETUP SUDOER FILES
sudoers_etc="/etc/sudoers.d/ft-psk"

$S_LOG -d $S_NAME -d "$sudoers_etc" "==============================="

echo "Defaults:zabbix !requiretty" | sudo EDITOR='tee' visudo --file=$sudoers_etc &>/dev/null
echo "zabbix ALL=(ALL) NOPASSWD:${S_DIR_PATH}/deploy.sh" | sudo EDITOR='tee -a' visudo --file=$sudoers_etc &>/dev/null
echo "zabbix ALL=(ALL) NOPASSWD:${S_DIR_PATH}/deploy-update.sh" | sudo EDITOR='tee -a' visudo --file=$sudoers_etc &>/dev/null

cat $sudoers_etc | $S_LOG -d "$S_NAME" -d "$sudoers_etc" -i

$S_LOG -d $S_NAME -d "$sudoers_etc" "==============================="

# DEPLOY KEY
if [ $new_psk -eq 1 ]; then
    $S_LOG -d "$S_NAME" -d "Installing Zabbix PSK Key"

    if [ ! -d "${psk_fld}" ]; then
        mkdir ${psk_fld}/
        chown zabbix:zabbix ${psk_fld}
    fi
    echo $psk_key >${zbx_psk_key}
    chown zabbix:zabbix ${zbx_psk_key}
    chmod 600 ${zbx_psk_key}

    $S_LOG -d "$S_NAME" -d "Installing Zabbix PSK Conf"
    echo "TLSConnect=psk" >$zbx_psk_conf
    echo "TLSAccept=psk" >>$zbx_psk_conf
    echo "TLSPSKIdentity=$psk_identity" >>$zbx_psk_conf
    echo "TLSPSKFile=${zbx_psk_key}" >>$zbx_psk_conf

    echo ""
    echo "####################################################"
    echo "###################  WARNING  ######################"
    echo "####################################################"
    echo ""
    echo "Update your server-side host configuration!"
    echo ""
    echo "psk_identity"
    grep -oP '^TLSPSKIdentity=\K.+' ${zbx_psk_conf}
    echo ""
    echo "psk_key"
    cat ${zbx_psk_key}
    echo ""
    echo "####################################################"
    echo "###################  WARNING  ######################"
    echo "####################################################"
    echo ""

fi

# DEPLOY CONF
if [ "${zbx_type}" = "agent" ]; then
    echo "UserParameter=ft-psk.identity, grep -oP '^TLSPSKIdentity=\K.+' ${zbx_psk_conf}\nUserParameter=ft-psk.key.lastmodified, stat --format=%Y ${zbx_psk_key}" >$zbx_psk_conf_userparam
    $S_LOG -s $? -d "$S_NAME" "Install Zabbix Agent UserParameters in $zbx_psk_conf_userparam"
fi

echo -e "systemctl restart zabbix-${zbx_type}*" | at now + 1 min &>/dev/null ## restart zabbix ${zbx_type} with a delay
$S_LOG -s $? -d "$S_NAME" "Scheduling Zabbix ${zbx_type} Restart"

$S_LOG -d "$S_NAME" "End $S_NAME"

exit
