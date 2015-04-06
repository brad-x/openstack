#!/bin/bash

#get config info
source ./config

#get primary NIC info
NIC=eth0
#setup the IP configuration for management NIC
echo "DEVICE=$NIC" > /etc/sysconfig/network-scripts/ifcfg-$NIC
echo "TYPE=\"Ethernet\"" >> /etc/sysconfig/network-scripts/ifcfg-$NIC
echo "NAME=\"$NIC\"" >> /etc/sysconfig/network-scripts/ifcfg-$NIC
echo "ONBOOT=\"yes\"" >> /etc/sysconfig/network-scripts/ifcfg-$NIC
echo "BOOTPROTO=static" >> /etc/sysconfig/network-scripts/ifcfg-$NIC
echo "IPADDR=\"$THISHOST_IP\"" >> /etc/sysconfig/network-scripts/ifcfg-$NIC
echo "NETMASK=\"$THISHOST_NETMASK\"" >> /etc/sysconfig/network-scripts/ifcfg-$NIC
echo "GATEWAY=\"$THISHOST_GATEWAY\"" >> /etc/sysconfig/network-scripts/ifcfg-$NIC
echo "DNS1=\"$THISHOST_DNS\"" >> /etc/sysconfig/network-scripts/ifcfg-$NIC

#create config file for Tunnel NIC
NIC=eth1
echo "DEVICE=$NIC" > /etc/sysconfig/network-scripts/ifcfg-$NIC
echo "TYPE=\"Ethernet\"" >> /etc/sysconfig/network-scripts/ifcfg-$NIC
echo "NAME=\"$NIC\"" >> /etc/sysconfig/network-scripts/ifcfg-$NIC
echo "ONBOOT=\"yes\"" >> /etc/sysconfig/network-scripts/ifcfg-$NIC
echo "BOOTPROTO=static" >> /etc/sysconfig/network-scripts/ifcfg-$NIC
echo "IPADDR=\"$THISHOST_TUNNEL_IP\"" >> /etc/sysconfig/network-scripts/ifcfg-$NIC
echo "NETMASK=\"$THISHOST_TUNNEL_NETMASK\"" >> /etc/sysconfig/network-scripts/ifcfg-$NIC


#setup hostname
echo "$THISHOST_NAME" > /etc/hostname
echo "$THISHOST_IP    $THISHOST_NAME" >> /etc/hosts

/usr/bin/systemctl restart network

mkdir -pv /etc/openstack-uncharted/

touch /etc/openstack-uncharted/ip-setup-done
