#!/bin/bash

source ./config

# Install dashboard
yum -y install openstack-dashboard httpd mod_wsgi memcached python-memcached

# Edit /etc/openstack-dashboard/local_settings
sed -i.bak "s/ALLOWED_HOSTS = \['horizon.example.com', 'localhost'\]/ALLOWED_HOSTS = ['*']/" /etc/openstack-dashboard/local_settings
sed -i 's/OPENSTACK_HOST = "127.0.0.1"/OPENSTACK_HOST = "'"$CONTROLLER_IP"'"/' /etc/openstack-dashboard/local_settings

#start dashboard
setsebool -P httpd_can_network_connect on
chown -R apache:apache /usr/share/openstack-dashboard/static
systemctl enable httpd.service memcached.service
systemctl start httpd.service memcached.service

mkdir -pv /etc/openstack-uncharted/

touch /etc/openstack-uncharted/horizon-setup-done

