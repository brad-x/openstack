#!/bin/bash

# Configuration Setup
source ./config

# Install NTP
yum -y install ntp cronie
systemctl enable ntpd.service
systemctl start ntpd.service
systemctl enable crond.service
systemctl start crond.service 

# Set up OpenStack repos
yum -y install yum-plugin-priorities epel-release ethtool
yum -y install http://rdo.fedorapeople.org/openstack-kilo/rdo-release-kilo.rpm
yum -y install openstack-utils
yum -y update

# Drop firewall and SELinux for now 
systemctl stop firewalld.service
systemctl disable firewalld.service
sed -i 's/enforcing/disabled/g' /etc/selinux/config
setenforce 0

# Disable IPv6 for now 
echo net.ipv6.conf.default.disable_ipv6=1 > /etc/sysctl.d/disable-ipv6.conf

sysctl -p

mkdir -pv /etc/openstack-uncharted/

touch /etc/openstack-uncharted/common-setup-done
