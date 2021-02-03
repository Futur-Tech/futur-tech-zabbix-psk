#!/usr/bin/env bash

# https://sbcode.net/zabbix/agent-psk-encryption/

mkdir /home/zabbix/
cd /home/zabbix

PSK_KEY=$(openssl rand -hex 32)
PSK_IDENTITY="ft-gen-$(hostname)"

echo $PSK_KEY > secret.psk
chown zabbix:zabbix secret.psk
chmod 640 secret.psk

ZABBIX_SETTING_FILE=/etc/zabbix/zabbix_agentd.d/ft-psk.conf

echo "TLSConnect=psk" > $ZABBIX_SETTING_FILE
echo "TLSAccept=psk" >> $ZABBIX_SETTING_FILE
echo "TLSPSKFile=/home/zabbix/secret.psk" >> $ZABBIX_SETTING_FILE
echo "TLSPSKIdentity=$PSK_IDENTITY" >> $ZABBIX_SETTING_FILE

systemctl restart zabbix-agent.service

echo "Update your server-side host configuration"
echo "PSK_KEY is"
echo $PSK_KEY
echo "PSK_IDENTITY is"
echo $PSK_IDENTITY

exit