#!/bin/bash

source ./config
source ./creds

# Install cinder controller
yum -y install openstack-cinder python-cinderclient python-oslo-db

# Create databases for cinder
mysql -u root -p${SQL_PWD} -e "CREATE DATABASE cinder;"
mysql -u root -p${SQL_PWD} -e "GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY '$SERVICE_PWD';"
mysql -u root -p${SQL_PWD} -e "GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY '$SERVICE_PWD';"
mysql -u root -p${SQL_PWD} -e "FLUSH PRIVILEGES;"

# Create keystone entries for cinder
keystone user-create --name cinder --pass $SERVICE_PWD
keystone user-role-add --user cinder --tenant service --role admin
keystone service-create --name cinder --type volume \
  --description "OpenStack Block Storage"
keystone service-create --name cinderv2 --type volumev2 \
  --description "OpenStack Block Storage"
keystone endpoint-create \
  --service-id $(keystone service-list | awk '/ volume / {print $2}') \
  --publicurl http://$CONTROLLER_IP:8776/v1/%\(tenant_id\)s \
  --internalurl http://$CONTROLLER_IP:8776/v1/%\(tenant_id\)s \
  --adminurl http://$CONTROLLER_IP:8776/v1/%\(tenant_id\)s \
  --region $REGION
keystone endpoint-create \
  --service-id $(keystone service-list | awk '/ volumev2 / {print $2}') \
  --publicurl http://$CONTROLLER_IP:8776/v2/%\(tenant_id\)s \
  --internalurl http://$CONTROLLER_IP:8776/v2/%\(tenant_id\)s \
  --adminurl http://$CONTROLLER_IP:8776/v2/%\(tenant_id\)s \
  --region $REGION

# Edit /etc/cinder/cinder.conf
openstack-config --set /etc/cinder/cinder.conf database connection mysql://cinder:$SERVICE_PWD@$CONTROLLER_IP/cinder

openstack-config --set /etc/cinder/cinder.conf DEFAULT rpc_backend rabbit
openstack-config --set /etc/cinder/cinder.conf DEFAULT rabbit_host $CONTROLLER_IP
openstack-config --set /etc/cinder/cinder.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/cinder/cinder.conf DEFAULT my_ip $CONTROLLER_IP
openstack-config --set /etc/cinder/cinder.conf DEFAULT glance_api_version 2
openstack-config --set /etc/cinder/cinder.conf DEFAULT glance_host ${CONTROLLER_IP}

openstack-config --set /etc/cinder/cinder.conf keystone_authtoken auth_uri http://$CONTROLLER_IP:5000/v2.0
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken identity_uri http://$CONTROLLER_IP:35357
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken admin_tenant_name service
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken admin_user cinder
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken admin_password $SERVICE_PWD

# Start cinder controller
su -s /bin/sh -c "cinder-manage db sync" cinder
systemctl enable openstack-cinder-api.service openstack-cinder-scheduler.service
systemctl start openstack-cinder-api.service openstack-cinder-scheduler.service

mkdir -pv /etc/openstack-uncharted/

touch /etc/openstack-uncharted/cinder-setup-done

