#!/bin/bash

source ./config

#install ntp
yum -y install ntp
systemctl enable ntpd.service
systemctl start ntpd.service

#openstack repos
yum -y install yum-plugin-priorities epel-release
yum -y install http://rdo.fedorapeople.org/openstack-juno/rdo-release-juno.rpm
yum -y upgrade
#yum -y install openstack-selinux

#loosen things up
systemctl stop firewalld.service
systemctl disable firewalld.service
sed -i 's/enforcing/disabled/g' /etc/selinux/config
echo 0 > /sys/fs/selinux/enforce

#get primary NIC info
for i in $(ls /sys/class/net); do
    if [ "$(cat /sys/class/net/$i/ifindex)" == '3' ]; then
        NIC=$i
        MY_MAC=$(cat /sys/class/net/$i/address)
        echo "$i ($MY_MAC)"
    fi
done

echo 'export OS_TENANT_NAME=admin' > creds
echo 'export OS_USERNAME=admin' >> creds
echo 'export OS_PASSWORD='"$ADMIN_PWD" >> creds
echo 'export OS_AUTH_URL=http://'"$CONTROLLER_IP"':35357/v2.0' >> creds
source ./creds

echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
echo 'net.ipv4.conf.all.rp_filter=0' >> /etc/sysctl.conf
echo 'net.ipv4.conf.default.rp_filter=0' >> /etc/sysctl.conf
sysctl -p

#install neutron
yum -y install openstack-neutron openstack-neutron-ml2 openstack-neutron-openvswitch

sed -i '0,/\[DEFAULT\]/s//\[DEFAULT\]\
rpc_backend = rabbit\
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
type_drivers = flat,gre\n\
tenant_network_types = gre\n\
mechanism_drivers = openvswitch" /etc/neutron/plugins/ml2/ml2_conf.ini

sed -i "/\[ml2_type_flat\]/a \
flat_networks = external" /etc/neutron/plugins/ml2/ml2_conf.ini

sed -i "/\[ml2_type_gre\]/a \
tunnel_id_ranges = 1:1000" /etc/neutron/plugins/ml2/ml2_conf.ini

sed -i "/\[securitygroup\]/a \
enable_security_group = True\n\
enable_ipset = True\n\
firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver\n\
[ovs]\n\
local_ip = $THISHOST_TUNNEL_IP\n\
enable_tunneling = True\n\
bridge_mappings = external:br-ex\n\
[agent]\n\
tunnel_types = gre" /etc/neutron/plugins/ml2/ml2_conf.ini

sed -i "/\[DEFAULT\]/a \
interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver\n\
use_namespaces = True\n\
external_network_bridge = br-ex" /etc/neutron/l3_agent.ini

sed -i "/\[DEFAULT\]/a \
interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver\n\
dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq\n\
use_namespaces = True" /etc/neutron/dhcp_agent.ini

sed -i "s/auth_url/#auth_url/g" /etc/neutron/metadata_agent.ini
sed -i "s/auth_region/#auth_region/g" /etc/neutron/metadata_agent.ini
sed -i "s/admin_tenant_name/#admin_tenant_name/g" /etc/neutron/metadata_agent.ini
sed -i "s/admin_user/#admin_user/g" /etc/neutron/metadata_agent.ini
sed -i "s/admin_password/#admin_password/g" /etc/neutron/metadata_agent.ini

sed -i "/\[DEFAULT\]/a \
auth_url = http://$CONTROLLER_IP:5000/v2.0\n\
auth_region = $REGION\n\
admin_tenant_name = service\n\
admin_user = neutron\n\
admin_password = $SERVICE_PWD\n\
nova_metadata_ip = $CONTROLLER_IP\n\
metadata_proxy_shared_secret = $META_PWD" /etc/neutron/metadata_agent.ini

#get external NIC info
for i in $(ls /sys/class/net); do
    if [ "$(cat /sys/class/net/$i/ifindex)" == '4' ]; then
        NIC=$i
        MY_MAC=$(cat /sys/class/net/$i/address)
        echo "$i ($MY_MAC)"
    fi
done

systemctl enable openvswitch.service
systemctl start openvswitch.service
ovs-vsctl add-br br-ex
ovs-vsctl add-port br-ex $NIC
ethtool -K $NIC gro off

ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
cp /usr/lib/systemd/system/neutron-openvswitch-agent.service \
  /usr/lib/systemd/system/neutron-openvswitch-agent.service.orig
sed -i 's,plugins/openvswitch/ovs_neutron_plugin.ini,plugin.ini,g' \
  /usr/lib/systemd/system/neutron-openvswitch-agent.service

systemctl enable neutron-openvswitch-agent.service neutron-l3-agent.service \
  neutron-dhcp-agent.service neutron-metadata-agent.service \
  neutron-ovs-cleanup.service
systemctl start neutron-openvswitch-agent.service neutron-l3-agent.service \
  neutron-dhcp-agent.service neutron-metadata-agent.service
