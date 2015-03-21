#!/bin/bash

source ./config

#get primary NIC info
NIC=eth0
MY_MAC=$(cat /sys/class/net/$NIC/address)
echo "$NIC ($MY_MAC)"

echo 'export OS_TENANT_NAME=admin' > creds
echo 'export OS_USERNAME=admin' >> creds
echo 'export OS_PASSWORD='"$ADMIN_PWD" >> creds
echo 'export OS_AUTH_URL=http://'"$CONTROLLER_IP"':35357/v2.0' >> creds
source ./creds

echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.d/ip-forward.conf
echo 'net.ipv4.conf.all.rp_filter=0' >> /etc/sysctl.d/ip-forward.conf
echo 'net.ipv4.conf.default.rp_filter=0' >> /etc/sysctl.d/ip-forward.conf

echo net.ipv6.conf.default.disable_ipv6=1 > /etc/sysctl.d/disable-ipv6.conf

sysctl -p

#install neutron
yum -y install openstack-neutron openstack-neutron-ml2 openstack-neutron-openvswitch

openstack-config --set /etc/neutron/neutron.conf DEFAULT rpc_backend rabbit
openstack-config --set /etc/neutron/neutron.conf DEFAULT rabbit_host $CONTROLLER_IP
openstack-config --set /etc/neutron/neutron.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/neutron/neutron.conf DEFAULT core_plugin ml2
openstack-config --set /etc/neutron/neutron.conf DEFAULT service_plugins router
openstack-config --set /etc/neutron/neutron.conf DEFAULT allow_overlapping_ips True

openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_uri http://$CONTROLLER_IP:5000/v2.0
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken identity_uri http://$CONTROLLER_IP:35357
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken admin_tenant_name service
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken admin_user neutron
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken admin_password $SERVICE_PWD

#### GRE ####
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers flat,gre
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types gre
####
#### VXLAN ####
#openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers flat,vxlan
#openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types vxlan
####
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers openvswitch

openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_flat flat_networks external

#### GRE ####
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_gre tunnel_id_ranges 1001:2000
####
#### VXLAN ####
#openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vxlan vni_ranges 1001:2000
#openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vxlan vxlan_group 224.0.0.1
####

openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_security_group True
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_ipset True
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver

openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs local_ip $THISHOST_TUNNEL_IP
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs enable_tunneling True
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs bridge_mappings external:br-ex

#### GRE ####
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini agent tunnel_types gre
####
#### VXLAN ####
#openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini agent tunnel_types vxlan
####
openstack-config --set /etc/neutron/l3_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
openstack-config --set /etc/neutron/l3_agent.ini DEFAULT use_namespaces True
openstack-config --set /etc/neutron/l3_agent.ini DEFAULT external_network_bridge br-ex

openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT dhcp_driver neutron.agent.linux.dhcp.Dnsmasq
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT use_namespaces True

openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT auth_url http://$CONTROLLER_IP:5000/v2.0
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT auth_region $REGION
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT admin_tenant_name service
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT admin_user neutron
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT admin_password $SERVICE_PWD
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_ip $CONTROLLER_IP
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT metadata_proxy_shared_secret $META_PWD

systemctl enable openvswitch.service
systemctl start openvswitch.service
ovs-vsctl add-br br-ex
ovs-vsctl add-port br-ex $NIC
ethtool -K $NIC gro off

ln -sf /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
cp /usr/lib/systemd/system/neutron-openvswitch-agent.service \
  /usr/lib/systemd/system/neutron-openvswitch-agent.service.orig
sed -i 's,plugins/openvswitch/ovs_neutron_plugin.ini,plugin.ini,g' \
  /usr/lib/systemd/system/neutron-openvswitch-agent.service

systemctl enable neutron-openvswitch-agent.service neutron-l3-agent.service \
  neutron-dhcp-agent.service neutron-metadata-agent.service \
  neutron-ovs-cleanup.service
systemctl start neutron-openvswitch-agent.service neutron-l3-agent.service \
  neutron-dhcp-agent.service neutron-metadata-agent.service
