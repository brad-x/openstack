#!/bin/bash

source ./config

# Install neutron
yum -y install openstack-neutron openstack-neutron-ml2 openstack-neutron-openvswitch

openstack-config --set /etc/neutron/neutron.conf DEFAULT rpc_backend rabbit
openstack-config --set /etc/neutron/neutron.conf DEFAULT rabbit_host $CONTROLLER_IP
openstack-config --set /etc/neutron/neutron.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/neutron/neutron.conf DEFAULT core_plugin ml2
openstack-config --set /etc/neutron/neutron.conf DEFAULT service_plugins router

openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_uri http://$CONTROLLER_IP:5000/v2.0
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken identity_uri http://$CONTROLLER_IP:35357
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken admin_tenant_name service
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken admin_user neutron
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken admin_password $SERVICE_PWD

openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers flat,vxlan
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types vxlan
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers openvswitch

openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vxlan vni_ranges 1001:2000
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vxlan vxlan_group 224.0.0.1

openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_security_group True
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_ipset True
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver

openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs local_ip $THISHOST_TUNNEL_IP
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs enable_tunneling True

openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini agent tunnel_types vxlan

systemctl enable openvswitch.service
systemctl start openvswitch.service

ln -sf /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini

cp /usr/lib/systemd/system/neutron-openvswitch-agent.service \
  /usr/lib/systemd/system/neutron-openvswitch-agent.service.orig
sed -i 's,plugins/openvswitch/ovs_neutron_plugin.ini,plugin.ini,g' \
  /usr/lib/systemd/system/neutron-openvswitch-agent.service

systemctl enable neutron-openvswitch-agent.service
systemctl start neutron-openvswitch-agent.service


