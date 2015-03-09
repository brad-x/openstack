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
yum -y install yum-plugin-priorities epel-release
yum -y install http://rdo.fedorapeople.org/openstack-juno/rdo-release-juno.rpm
yum -y install openstack-utils
yum -y update

# Drop firewall and SELinux for now 
systemctl stop firewalld.service
systemctl disable firewalld.service
sed -i 's/enforcing/disabled/g' /etc/selinux/config
setenforce 0

mkdir /etc/openstack-uncharted/

touch /etc/openstack-uncharted/common-setup-done
