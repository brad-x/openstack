#!/bin/bash

source ./config
source ./creds

# Install the nova controller
yum -y install openstack-nova-api openstack-nova-cert openstack-nova-conductor \
  openstack-nova-console openstack-nova-novncproxy openstack-nova-scheduler \
  python-novaclient

# Create databases for nova
mysql -u root -p${SQL_PWD} -e "CREATE DATABASE nova;"
mysql -u root -p${SQL_PWD} -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '$SERVICE_PWD';"
mysql -u root -p${SQL_PWD} -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '$SERVICE_PWD';"
mysql -u root -p${SQL_PWD} -e "FLUSH PRIVILEGES;"

# Create keystone entries for nova
keystone user-create --name nova --pass $SERVICE_PWD
keystone user-role-add --user nova --tenant service --role admin
keystone service-create --name nova --type compute \
  --description "OpenStack Compute"
keystone endpoint-create \
  --service-id $(keystone service-list | awk '/ compute / {print $2}') \
  --publicurl http://$CONTROLLER_IP:8774/v2/%\(tenant_id\)s \
  --internalurl http://$CONTROLLER_IP:8774/v2/%\(tenant_id\)s \
  --adminurl http://$CONTROLLER_IP:8774/v2/%\(tenant_id\)s \
  --region $REGION

# Edit /etc/nova/nova.conf
openstack-config --set /etc/nova/nova.conf database connection mysql://nova:$SERVICE_PWD@$CONTROLLER_IP/nova

openstack-config --set /etc/nova/nova.conf DEFAULT rpc_backend rabbit
openstack-config --set /etc/nova/nova.conf DEFAULT rabbit_host $CONTROLLER_IP
openstack-config --set /etc/nova/nova.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/nova/nova.conf DEFAULT my_ip $CONTROLLER_IP
openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_listen $CONTROLLER_IP
openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address $CONTROLLER_IP
openstack-config --set /etc/nova/nova.conf DEFAULT network_api_class nova.network.neutronv2.api.API
openstack-config --set /etc/nova/nova.conf DEFAULT security_group_api neutron
openstack-config --set /etc/nova/nova.conf DEFAULT linuxnet_interface_driver nova.network.linux_net.LinuxOVSInterfaceDriver
openstack-config --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver
openstack-config --set /etc/nova/nova.conf DEFAULT dhcp_domain ${DHCP_DOMAIN}
openstack-config --set /etc/nova/nova.conf DEFAULT default_availability_zone \"${DEFAULT_AZ}\"

openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_uri http://$CONTROLLER_IP:5000/v2.0
openstack-config --set /etc/nova/nova.conf keystone_authtoken identity_uri http://$CONTROLLER_IP:35357
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_tenant_name service
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_user nova
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_password $SERVICE_PWD

openstack-config --set /etc/nova/nova.conf glance host $CONTROLLER_IP

openstack-config --set /etc/nova/nova.conf neutron url http://$CONTROLLER_IP:9696
openstack-config --set /etc/nova/nova.conf neutron auth_strategy keystone
openstack-config --set /etc/nova/nova.conf neutron admin_auth_url http://$CONTROLLER_IP:35357/v2.0
openstack-config --set /etc/nova/nova.conf neutron admin_tenant_name service
openstack-config --set /etc/nova/nova.conf neutron admin_username neutron
openstack-config --set /etc/nova/nova.conf neutron admin_password $SERVICE_PWD
openstack-config --set /etc/nova/nova.conf neutron service_metadata_proxy True
openstack-config --set /etc/nova/nova.conf neutron metadata_proxy_shared_secret $META_PWD

# Start nova
su -s /bin/sh -c "nova-manage db sync" nova

systemctl enable openstack-nova-api.service openstack-nova-cert.service \
  openstack-nova-consoleauth.service openstack-nova-scheduler.service \
  openstack-nova-conductor.service openstack-nova-novncproxy.service
systemctl start openstack-nova-api.service openstack-nova-cert.service \
  openstack-nova-consoleauth.service openstack-nova-scheduler.service \
  openstack-nova-conductor.service openstack-nova-novncproxy.service

mkdir -pv /etc/openstack-uncharted/

touch /etc/openstack-uncharted/nova-setup-done

