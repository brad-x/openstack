#!/bin/bash

source ./config
source ./creds

# Install glance
yum -y install openstack-glance python-glanceclient

# Create databases for glance
mysql -u root -p${SQL_PWD} -e "CREATE DATABASE glance;"
mysql -u root -p${SQL_PWD} -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$SERVICE_PWD';"
mysql -u root -p${SQL_PWD} -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '$SERVICE_PWD';"
mysql -u root -p${SQL_PWD} -e "FLUSH PRIVILEGES;"

# Create keystone entries for glance
keystone user-create --name glance --pass $SERVICE_PWD
keystone user-role-add --user glance --tenant service --role admin
keystone service-create --name glance --type image \
  --description "OpenStack Image Service"
keystone endpoint-create \
  --service-id $(keystone service-list | awk '/ image / {print $2}') \
  --publicurl http://$CONTROLLER_IP:9292 \
  --internalurl http://$CONTROLLER_IP:9292 \
  --adminurl http://$CONTROLLER_IP:9292 \
  --region $REGION

# Edit /etc/glance/glance-api.conf

openstack-config --set /etc/glance/glance-api.conf database connection mysql://glance:${SERVICE_PWD}@${CONTROLLER_IP}/glance

openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_uri http://${CONTROLLER_IP}:5000/v2.0
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken identity_uri http://$CONTROLLER_IP:35357
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken admin_tenant_name service
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken admin_user glance
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken admin_password $SERVICE_PWD

openstack-config --set /etc/glance/glance-api.conf paste_deploy flavor keystone

openstack-config --set /etc/glance/glance-api.conf glance_store default_store file
openstack-config --set /etc/glance/glance-api.conf glance_store filesystem_store_datadir /var/lib/glance/images/

# Edit /etc/glance/glance-registry.conf

openstack-config --set /etc/glance/glance-registry.conf database connection mysql://glance:${SERVICE_PWD}@${CONTROLLER_IP}/glance
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_uri http://${CONTROLLER_IP}:5000/v2.0
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken identity_uri http://$CONTROLLER_IP:35357
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken admin_tenant_name service
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken admin_user glance
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken admin_password $SERVICE_PWD
openstack-config --set /etc/glance/glance-registry.conf paste_deploy flavor keystone

su -s /bin/sh -c "glance-manage db_sync" glance

# Start glance
systemctl enable openstack-glance-api.service openstack-glance-registry.service
systemctl start openstack-glance-api.service openstack-glance-registry.service

# Upload Cirros image to glance
yum -y install wget
wget http://cdn.download.cirros-cloud.net/0.3.3/cirros-0.3.3-x86_64-disk.img
glance image-create --name "cirros-0.3.3-x86_64" --file cirros-0.3.3-x86_64-disk.img \
  --disk-format qcow2 --container-format bare --is-public True --progress

mkdir -pv /etc/openstack-uncharted/

touch /etc/openstack-uncharted/glance-setup-done

