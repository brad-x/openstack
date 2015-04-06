#!/bin/bash

source ./config

# Networking adjustments

echo 'net.ipv4.conf.all.rp_filter=0' >> /etc/sysctl.d/rp-filter.conf
echo 'net.ipv4.conf.default.rp_filter=0' >> /etc/sysctl.d/rp-filter.conf

echo net.ipv6.conf.default.disable_ipv6=1 > /etc/sysctl.d/disable-ipv6.conf

sysctl -p

#nova compute
yum -y install openstack-nova-compute sysfsutils libvirt-daemon-config-nwfilter

openstack-config --set /etc/nova/nova.conf DEFAULT rpc_backend rabbit
openstack-config --set /etc/nova/nova.conf DEFAULT rabbit_host $CONTROLLER_IP
openstack-config --set /etc/nova/nova.conf DEFAULT auth_strategy keystone 
openstack-config --set /etc/nova/nova.conf DEFAULT my_ip $THISHOST_IP
openstack-config --set /etc/nova/nova.conf DEFAULT vnc_enabled True
openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_listen 0.0.0.0
openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address $THISHOST_IP
openstack-config --set /etc/nova/nova.conf DEFAULT novncproxy_base_url http://$CONTROLLER_IP:6080/vnc_auto.html
openstack-config --set /etc/nova/nova.conf DEFAULT network_api_class nova.network.neutronv2.api.API
openstack-config --set /etc/nova/nova.conf DEFAULT security_group_api neutron
openstack-config --set /etc/nova/nova.conf DEFAULT linuxnet_interface_driver nova.network.linux_net.LinuxOVSInterfaceDriver
openstack-config --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver

openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_uri http://$CONTROLLER_IP:5000/v2.0
openstack-config --set /etc/nova/nova.conf keystone_authtoken identity_uri http://$CONTROLLER_IP:35357
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_tenant_name service
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_user nova
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_password $SERVICE_PWD

openstack-config --set /etc/nova/nova.conf glance host $CONTROLLER_IP

#if compute node is virtual - change virt_type to qemu
if [ $(egrep -c '(vmx|svm)' /proc/cpuinfo) == "0" ]; then
    openstack-config --set /etc/nova/nova.conf libvirt virt_type qemu
fi

#install neutron
yum -y install openstack-neutron-ml2 openstack-neutron-openvswitch

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

openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs local_ip $THISHOST_TUNNEL_IP
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs enable_tunneling True

#openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini agent tunnel_types gre
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini agent tunnel_types vxlan

systemctl enable openvswitch.service
systemctl start openvswitch.service

openstack-config --set /etc/nova/nova.conf neutron url http://$CONTROLLER_IP:9696
openstack-config --set /etc/nova/nova.conf neutron auth_strategy keystone
openstack-config --set /etc/nova/nova.conf neutron admin_auth_url http://$CONTROLLER_IP:35357/v2.0
openstack-config --set /etc/nova/nova.conf neutron admin_tenant_name service
openstack-config --set /etc/nova/nova.conf neutron admin_username neutron
openstack-config --set /etc/nova/nova.conf neutron admin_password $SERVICE_PWD

ln -sf /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini

cp /usr/lib/systemd/system/neutron-openvswitch-agent.service \
  /usr/lib/systemd/system/neutron-openvswitch-agent.service.orig
sed -i 's,plugins/openvswitch/ovs_neutron_plugin.ini,plugin.ini,g' \
  /usr/lib/systemd/system/neutron-openvswitch-agent.service

systemctl enable libvirtd.service openstack-nova-compute.service
systemctl start libvirtd.service
systemctl start openstack-nova-compute.service
systemctl enable neutron-openvswitch-agent.service
systemctl start neutron-openvswitch-agent.service

#cinder storage node
#pvcreate /dev/sdb
#vgcreate cinder-volumes /dev/sdb

yum -y install openstack-cinder targetcli python-oslo-db MySQL-python

echo "192.168.0.6:/export/openstack" > /etc/cinder/nfsshares

openstack-config --set /etc/cinder/cinder.conf database connection mysql://cinder:$SERVICE_PWD@$CONTROLLER_IP/cinder

openstack-config --set /etc/cinder/cinder.conf DEFAULT rpc_backend rabbit
openstack-config --set /etc/cinder/cinder.conf DEFAULT rabbit_host $CONTROLLER_IP
openstack-config --set /etc/cinder/cinder.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/cinder/cinder.conf DEFAULT my_ip $THISHOST_IP
#openstack-config --set /etc/cinder/cinder.conf DEFAULT iscsi_helper lioadm
openstack-config --set /etc/cinder/cinder.conf DEFAULT volume_driver cinder.volume.drivers.nfs.NfsDriver
openstack-config --set /etc/cinder/cinder.conf DEFAULT nfs_shares_config /etc/cinder/nfsshares
openstack-config --set /etc/cinder/cinder.conf DEFAULT glance_api_version 2
openstack-config --set /etc/cinder/cinder.conf DEFAULT glance_host ${CONTROLLER_IP}

openstack-config --set /etc/cinder/cinder.conf keystone_authtoken auth_uri http://$CONTROLLER_IP:5000/v2.0
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken identity_uri http://$CONTROLLER_IP:35357
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken admin_tenant_name service
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken admin_user cinder
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken admin_password $SERVICE_PWD

systemctl enable openstack-cinder-volume.service # target.service
systemctl start openstack-cinder-volume.service # target.service

echo 'export OS_TENANT_NAME=admin' > creds
echo 'export OS_USERNAME=admin' >> creds
echo 'export OS_PASSWORD='"$ADMIN_PWD" >> creds
echo 'export OS_AUTH_URL=http://'"$CONTROLLER_IP"':35357/v2.0' >> creds
source ./creds
