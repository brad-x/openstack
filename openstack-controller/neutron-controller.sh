#!/bin/bash

source ./config
source ./creds

# Install neutron
yum -y install openstack-neutron openstack-neutron-ml2 python-neutronclient which

# Create databases for neutron 
mysql -u root -p${SQL_PWD} -e "CREATE DATABASE neutron;"
mysql -u root -p${SQL_PWD} -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY '$SERVICE_PWD';"
mysql -u root -p${SQL_PWD} -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY '$SERVICE_PWD';"
mysql -u root -p${SQL_PWD} -e "FLUSH PRIVILEGES;"

# Create keystone entries for neutron
keystone user-create --name neutron --pass $SERVICE_PWD
keystone user-role-add --user neutron --tenant service --role admin
keystone service-create --name neutron --type network \
  --description "OpenStack Networking"
keystone endpoint-create \
  --service-id $(keystone service-list | awk '/ network / {print $2}') \
  --publicurl http://$CONTROLLER_IP:9696 \
  --internalurl http://$CONTROLLER_IP:9696 \
  --adminurl http://$CONTROLLER_IP:9696 \
  --region $REGION

# Edit /etc/neutron/neutron.conf
openstack-config --set /etc/neutron/neutron.conf database connection mysql://neutron:$SERVICE_PWD@$CONTROLLER_IP/neutron

SERVICE_TENANT_ID=$(keystone tenant-list | awk '/ service / {print $2}')

openstack-config --set /etc/neutron/neutron.conf DEFAULT rpc_backend rabbit
openstack-config --set /etc/neutron/neutron.conf DEFAULT rabbit_host $CONTROLLER_IP
openstack-config --set /etc/neutron/neutron.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/neutron/neutron.conf DEFAULT core_plugin ml2
openstack-config --set /etc/neutron/neutron.conf DEFAULT service_plugins router
openstack-config --set /etc/neutron/neutron.conf DEFAULT allow_overlapping_ips True
openstack-config --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_status_changes True
openstack-config --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_data_changes True
openstack-config --set /etc/neutron/neutron.conf DEFAULT nova_url http://$CONTROLLER_IP:8774/v2
openstack-config --set /etc/neutron/neutron.conf DEFAULT nova_admin_auth_url http://$CONTROLLER_IP:35357/v2.0
openstack-config --set /etc/neutron/neutron.conf DEFAULT nova_region_name $REGION
openstack-config --set /etc/neutron/neutron.conf DEFAULT nova_admin_username nova
openstack-config --set /etc/neutron/neutron.conf DEFAULT nova_admin_tenant_id $SERVICE_TENANT_ID
openstack-config --set /etc/neutron/neutron.conf DEFAULT nova_admin_password $SERVICE_PWD

openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_uri http://$CONTROLLER_IP:5000/v2.0
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken identity_uri http://$CONTROLLER_IP:35357
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken admin_tenant_name service
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken admin_user neutron
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken admin_password $SERVICE_PWD

#openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers flat,gre
#openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types gre
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers flat,vxlan
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types vxlan
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers openvswitch

#openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_gre tunnel_id_ranges 1001:2000
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vxlan vni_ranges 1001:2000
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vxlan vxlan_group 224.0.0.1

openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_security_group True
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_ipset True
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver

# Start neutron
ln -sf /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade juno" neutron

systemctl restart openstack-nova-api.service openstack-nova-scheduler.service \
  openstack-nova-conductor.service

systemctl enable neutron-server.service
systemctl start neutron-server.service

mkdir -pv /etc/openstack-uncharted/

touch /etc/openstack-uncharted/neutron-setup-done

