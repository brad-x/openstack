#!/bin/bash

source ./config

#nova compute
yum -y install openstack-nova-compute sysfsutils libvirt-daemon-config-nwfilter
yum -y install qemu-kvm-rhev

openstack-config --set /etc/nova/nova.conf DEFAULT reserved_host_memory_mb 65536
openstack-config --set /etc/nova/nova.conf DEFAULT rpc_backend rabbit
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
openstack-config --set /etc/nova/nova.conf DEFAULT dhcp_domain ${DHCP_DOMAIN}
openstack-config --set /etc/nova/nova.conf DEFAULT cert /etc/nova/cert-key.pem

openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_uri http://$CONTROLLER_IP:5000/v2.0
openstack-config --set /etc/nova/nova.conf keystone_authtoken identity_uri http://$CONTROLLER_IP:35357
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_tenant_name service
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_user nova
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_password $SERVICE_PWD

openstack-config --set /etc/nova/nova.conf glance host $CONTROLLER_IP

openstack-config --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_host $CONTROLLER_IP

openstack-config --set /etc/nova/nova.conf neutron url http://$CONTROLLER_IP:9696
openstack-config --set /etc/nova/nova.conf neutron auth_strategy keystone
openstack-config --set /etc/nova/nova.conf neutron admin_auth_url http://$CONTROLLER_IP:35357/v2.0
openstack-config --set /etc/nova/nova.conf neutron admin_tenant_name service
openstack-config --set /etc/nova/nova.conf neutron admin_username neutron
openstack-config --set /etc/nova/nova.conf neutron admin_password $SERVICE_PWD

#if compute node is virtual - change virt_type to qemu
if [ $(egrep -c '(vmx|svm)' /proc/cpuinfo) == "0" ]; then
    openstack-config --set /etc/nova/nova.conf libvirt virt_type qemu
fi

systemctl enable libvirtd.service openstack-nova-compute.service
systemctl start libvirtd.service
systemctl start openstack-nova-compute.service
systemctl enable ksm.service
systemctl start ksm.service
