#!/bin/bash

source ./config

yum install openvswitch

echo "DEVICE=br-ex" > /etc/sysconfig/network-scripts/ifcfg-br-ex
echo "DEVICETYPE=ovs" >> /etc/sysconfig/network-scripts/ifcfg-br-ex
echo "TYPE=OVSBridge" >> /etc/sysconfig/network-scripts/ifcfg-br-ex
echo "BOOTPROTO=static" >> /etc/sysconfig/network-scripts/ifcfg-br-ex
echo "IPADDR=\"$THISHOST_IP\"" >> /etc/sysconfig/network-scripts/ifcfg-br-ex
echo "NETMASK=\"$THISHOST_NETMASK\"" >> /etc/sysconfig/network-scripts/ifcfg-br-ex
echo "GATEWAY=\"$THISHOST_GATEWAY\"" >> /etc/sysconfig/network-scripts/ifcfg-br-ex
echo "DNS1=\"$THISHOST_DNS\"" >> /etc/sysconfig/network-scripts/ifcfg-br-ex
echo "ONBOOT=yes" >> /etc/sysconfig/network-scripts/ifcfg-br-ex
echo "MTU=9000" >> /etc/sysconfig/network-scripts/ifcfg-br-ex

#get primary NIC info
NIC=eth0
#setup the IP configuration for management NIC
echo "DEVICE=$NIC" > /etc/sysconfig/network-scripts/ifcfg-$NIC
echo "TYPE=OVSPort" >> /etc/sysconfig/network-scripts/ifcfg-$NIC
echo "DEVICETYPE=ovs" >> /etc/sysconfig/network-scripts/ifcfg-$NIC
echo "OVS_BRIDGE=br-ex" >> /etc/sysconfig/network-scripts/ifcfg-$NIC
echo "ONBOOT=yes" >> /etc/sysconfig/network-scripts/ifcfg-$NIC

#create config file for Tunnel NIC
NIC=eth1
echo "DEVICE=$NIC" > /etc/sysconfig/network-scripts/ifcfg-$NIC
echo "TYPE=\"Ethernet\"" >> /etc/sysconfig/network-scripts/ifcfg-$NIC
echo "NAME=\"$NIC\"" >> /etc/sysconfig/network-scripts/ifcfg-$NIC
echo "ONBOOT=\"yes\"" >> /etc/sysconfig/network-scripts/ifcfg-$NIC
echo "BOOTPROTO=static" >> /etc/sysconfig/network-scripts/ifcfg-$NIC
echo "IPADDR=\"$THISHOST_TUNNEL_IP\"" >> /etc/sysconfig/network-scripts/ifcfg-$NIC
echo "NETMASK=\"$THISHOST_TUNNEL_NETMASK\"" >> /etc/sysconfig/network-scripts/ifcfg-$NIC

