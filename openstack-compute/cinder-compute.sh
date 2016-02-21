#!/bin/bash

source ./config

# Install Cinder

yum -y install openstack-cinder targetcli python-oslo-db MySQL-python

openstack-config --set /etc/cinder/cinder.conf database connection mysql://cinder:$SERVICE_PWD@$CONTROLLER_IP/cinder

openstack-config --set /etc/cinder/cinder.conf DEFAULT rpc_backend rabbit
openstack-config --set /etc/cinder/cinder.conf DEFAULT rabbit_host $CONTROLLER_IP
openstack-config --set /etc/cinder/cinder.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/cinder/cinder.conf DEFAULT host volumes
openstack-config --set /etc/cinder/cinder.conf DEFAULT my_ip $THISHOST_IP
openstack-config --set /etc/cinder/cinder.conf DEFAULT glance_api_version 2
openstack-config --set /etc/cinder/cinder.conf DEFAULT glance_host ${CONTROLLER_IP}
openstack-config --set /etc/cinder/cinder.conf DEFAULT default_availability_zone "\"${DEFAULT_AZ}\""
openstack-config --set /etc/cinder/cinder.conf DEFAULT storage_availability_zone "\"${DEFAULT_AZ}\""

openstack-config --set /etc/cinder/cinder.conf keystone_authtoken auth_uri http://$CONTROLLER_IP:5000/v2.0
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken identity_uri http://$CONTROLLER_IP:35357
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken admin_tenant_name service
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken admin_user cinder
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken admin_password $SERVICE_PWD

systemctl enable openstack-cinder-volume.service
systemctl start openstack-cinder-volume.service

echo 'export OS_TENANT_NAME=admin' > creds
echo 'export OS_USERNAME=admin' >> creds
echo 'export OS_PASSWORD='"$ADMIN_PWD" >> creds
echo 'export OS_AUTH_URL=http://'"$CONTROLLER_IP"':35357/v2.0' >> creds
source ./creds

