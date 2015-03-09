#!/bin/bash

# Networking adjustments

echo 'net.ipv4.conf.all.rp_filter=0' >> /etc/sysctl.conf
echo 'net.ipv4.conf.default.rp_filter=0' >> /etc/sysctl.conf
sysctl -p

#get primary NIC info
for i in $(ls /sys/class/net); do
    if [ "$(cat /sys/class/net/$i/ifindex)" == '3' ]; then
        NIC=$i
        MY_MAC=$(cat /sys/class/net/$i/address)
        echo "$i ($MY_MAC)"
    fi
done

#nova compute
yum -y install openstack-nova-compute sysfsutils libvirt-daemon-config-nwfilter

sed -i.bak "/\[DEFAULT\]/a \
rpc_backend = rabbit\n\
rabbit_host = $CONTROLLER_IP\n\
auth_strategy = keystone\n\
my_ip = $THISHOST_IP\n\
vnc_enabled = True\n\
vncserver_listen = 0.0.0.0\n\
vncserver_proxyclient_address = $THISHOST_IP\n\
novncproxy_base_url = http://$CONTROLLER_IP:6080/vnc_auto.html\n\
network_api_class = nova.network.neutronv2.api.API\n\
security_group_api = neutron\n\
linuxnet_interface_driver = nova.network.linux_net.LinuxOVSInterfaceDriver\n\
firewall_driver = nova.virt.firewall.NoopFirewallDriver" /etc/nova/nova.conf

sed -i "/\[keystone_authtoken\]/a \
auth_uri = http://$CONTROLLER_IP:5000/v2.0\n\
identity_uri = http://$CONTROLLER_IP:35357\n\
admin_tenant_name = service\n\
admin_user = nova\n\
admin_password = $SERVICE_PWD" /etc/nova/nova.conf

sed -i "/\[glance\]/a host = $CONTROLLER_IP" /etc/nova/nova.conf

#if compute node is virtual - change virt_type to qemu
if [ $(egrep -c '(vmx|svm)' /proc/cpuinfo) == "0" ]; then
    sed -i '/\[libvirt\]/a virt_type = qemu' /etc/nova/nova.conf
fi

#install neutron
yum -y install openstack-neutron-ml2 openstack-neutron-openvswitch

sed -i '0,/\[DEFAULT\]/s//\[DEFAULT\]\
rpc_backend = rabbit\n\
rabbit_host = '"$CONTROLLER_IP"'\
auth_strategy = keystone\
core_plugin = ml2\
service_plugins = router\
allow_overlapping_ips = True/' /etc/neutron/neutron.conf

sed -i "/\[keystone_authtoken\]/a \
auth_uri = http://$CONTROLLER_IP:5000/v2.0\n\
identity_uri = http://$CONTROLLER_IP:35357\n\
admin_tenant_name = service\n\
admin_user = neutron\n\
admin_password = $SERVICE_PWD" /etc/neutron/neutron.conf

#edit /etc/neutron/plugins/ml2/ml2_conf.ini
sed -i "/\[ml2\]/a \
type_drivers = flat,vxlan\n\
tenant_network_types = vxlan\n\
mechanism_drivers = openvswitch" /etc/neutron/plugins/ml2/ml2_conf.ini

openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vxlan vni_ranges 1001:2000
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vxlan vxlan_group 224.0.0.1

openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_security_group True
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_ipset True
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver

openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs local_ip $THISHOST_TUNNEL_IP
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs enable_tunneling True
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs bridge_mappings external:br-ex

openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini agent tunnel_types vxlan

systemctl enable openvswitch.service
systemctl start openvswitch.service

sed -i "/\[neutron\]/a \
url = http://$CONTROLLER_IP:9696\n\
auth_strategy = keystone\n\
admin_auth_url = http://$CONTROLLER_IP:35357/v2.0\n\
admin_tenant_name = service\n\
admin_username = neutron\n\
admin_password = $SERVICE_PWD" /etc/nova/nova.conf

ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini

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
pvcreate /dev/sdb
vgcreate cinder-volumes /dev/sdb

yum -y install openstack-cinder targetcli python-oslo-db MySQL-python

sed -i.bak "/\[database\]/a connection = mysql://cinder:$SERVICE_PWD@$CONTROLLER_IP/cinder" /etc/cinder/cinder.conf
sed -i '0,/\[DEFAULT\]/s//\[DEFAULT\]\
rpc_backend = rabbit\
rabbit_host = '"$CONTROLLER_IP"'\
auth_strategy = keystone\
my_ip = '"$THISHOST_IP"'\
iscsi_helper = lioadm/' /etc/cinder/cinder.conf
sed -i "/\[keystone_authtoken\]/a \
auth_uri = http://$CONTROLLER_IP:5000/v2.0\n\
identity_uri = http://$CONTROLLER_IP:35357\n\
admin_tenant_name = service\n\
admin_user = cinder\n\
admin_password = $SERVICE_PWD" /etc/cinder/cinder.conf

systemctl enable openstack-cinder-volume.service target.service
systemctl start openstack-cinder-volume.service target.service

echo 'export OS_TENANT_NAME=admin' > creds
echo 'export OS_USERNAME=admin' >> creds
echo 'export OS_PASSWORD='"$ADMIN_PWD" >> creds
echo 'export OS_AUTH_URL=http://'"$CONTROLLER_IP"':35357/v2.0' >> creds
source ./creds
