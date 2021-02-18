#!/usr/bin/env bash

cd /usr/local/zabbix

PSK_KEY=$(openssl rand -hex 32)
PSK_IDENTITY="ft-gen-$(hostname)-proxy"

echo $PSK_KEY > secret-proxy.psk
chown zabbixproxy:nobody secret-proxy.psk
chmod 600 secret-proxy.psk

ZABBIX_SETTING_FILE=/usr/local/zabbix/etc/zabbix_proxy.conf.d/ft-psk.conf

echo "TLSConnect=psk" > $ZABBIX_SETTING_FILE
echo "TLSAccept=psk" >> $ZABBIX_SETTING_FILE
echo "TLSPSKFile=/usr/local/zabbix/secret-proxy.psk" >> $ZABBIX_SETTING_FILE
echo "TLSPSKIdentity=$PSK_IDENTITY" >> $ZABBIX_SETTING_FILE

synoservice --restart pkgctl-zabbix

echo "PROXY PSK SETUP DONE"
echo "Update your server-side proxy configuration"
echo "PSK_IDENTITY="
echo $PSK_IDENTITY
echo "PSK_KEY="
echo $PSK_KEY

exit