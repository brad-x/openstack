#!/bin/bash

source ./config
source ./creds

# Install database for heat ########################################

mysql -u root -p${SQL_PWD} -e "CREATE DATABASE heat;"

mysql -u root -p${SQL_PWD} -e "GRANT ALL PRIVILEGES ON heat.* TO 'heat'@'localhost' IDENTIFIED BY '$SERVICE_PWD';"
mysql -u root -p${SQL_PWD} -e "GRANT ALL PRIVILEGES ON heat.* TO 'heat'@'%' IDENTIFIED BY '$SERVICE_PWD';"
mysql -u root -p${SQL_PWD} -e "FLUSH PRIVILEGES;"



# Keystone config for heat ###########################################################

keystone user-create --name heat --pass $SERVICE_PWD

keystone user-role-add --user heat --tenant service --role admin

keystone role-create --name heat_stack_owner

keystone user-role-add --user demo --tenant demo --role heat_stack_owner

keystone role-create --name heat_stack_user

keystone service-create --name heat --type orchestration --description "Orchestration"

keystone service-create --name heat --type cloudformation --description "Cloudformation"

keystone endpoint-create \
  --service-id $(keystone service-list | awk '/ orchestration / {print $2}') \
  --publicurl http://$CONTROLLER_IP:8004/v1/%\(tenant_id\)s \
  --internalurl http://$CONTROLLER_IP:8004/v1/%\(tenant_id\)s \
  --adminurl http://$CONTROLLER_IP:8004/v1/%\(tenant_id\)s \
  --region $REGION

keystone endpoint-create \
  --service-id $(keystone service-list | awk '/ cloudformation / {print $2}') \
  --publicurl http://$CONTROLLER_IP:8000/v1 \
  --internalurl http://$CONTROLLER_IP:8000/v1 \
  --adminurl http://$CONTROLLER_IP:8000/v1 \
  --region $REGION

# Install packages for heat #############################################################################

yum -y install openstack-heat-api openstack-heat-api-cfn openstack-heat-engine python-heatclient

# config changes to heat.conf ##########################################################################################

openstack-config --set /etc/heat/heat.conf database connection mysql://heat:$SERVICE_PWD@$CONTROLLER_IP/heat

openstack-config --set /etc/heat/heat.conf DEFAULT rpc_backend rabbit
openstack-config --set /etc/heat/heat.conf DEFAULT rabbit_host $CONTROLLER_IP
# openstack-config --set /etc/heat/heat.conf DEFAULT rabbit_password RABBIT_PASS####################change this!!!!!

openstack-config --set /etc/heat/heat.conf keystone_authtoken auth_uri http://$CONTROLLER_IP:5000/v2.0
openstack-config --set /etc/heat/heat.conf keystone_authtoken identity_uri http://$CONTROLLER_IP:35357
openstack-config --set /etc/heat/heat.conf keystone_authtoken admin_tenant_name service
openstack-config --set /etc/heat/heat.conf keystone_authtoken admin_user heat
openstack-config --set /etc/heat/heat.conf keystone_authtoken admin_password $SERVICE_PWD

openstack-config --set /etc/heat/heat.conf ec2authtoken auth_uri http://$CONTROLLER_IP:5000/v2.0

openstack-config --set /etc/heat/heat.conf DEFAULT heat_metadata_server_url http://$CONTROLLER_IP:8000
openstack-config --set /etc/heat/heat.conf DEFAULT heat_waitcondition_server_url http://$CONTROLLER_IP:8000/v1/waitcondition

su -s /bin/sh -c "heat-manage db_sync" heat

# Enable services at startup and start heat services #############################################################################

systemctl enable openstack-heat-api.service openstack-heat-api-cfn.service openstack-heat-engine.service
systemctl start openstack-heat-api.service openstack-heat-api-cfn.service openstack-heat-engine.service
