#!/bin/bash

source ./config
source ./creds

yum -y install openstack-trove python-troveclient

# Create database for trove ########################################

mysql -u root -p${SQL_PWD} -e "CREATE DATABASE trove;"
mysql -u root -p${SQL_PWD} -e "GRANT ALL PRIVILEGES ON trove.* TO 'trove'@'localhost' IDENTIFIED BY '$SERVICE_PWD';"
mysql -u root -p${SQL_PWD} -e "GRANT ALL PRIVILEGES ON trove.* TO 'trove'@'%' IDENTIFIED BY '$SERVICE_PWD';"
mysql -u root -p${SQL_PWD} -e "FLUSH PRIVILEGES;"

# Keystone authentication for Trove ###########################################

keystone user-create --name trove --pass $SERVICE_PWD
keystone user-role-add --user trove --tenant service --role admin
keystone service-create --name trove --type database --description "OpenStack Database Service"

keystone endpoint-create \
  --service-id $(keystone service-list | awk '/ trove / {print $2}') \
  --publicurl http://$CONTROLLER_IP:8779/v1.0/%\(tenant_id\)s \
  --internalurl http://$CONTROLLER_IP:8779/v1.0/%\(tenant_id\)s \
  --adminurl http://$CONTROLLER_IP:8779/v1.0/%\(tenant_id\)s \
  --region $REGION


# Config changes for all Trove config files ###########################################################

openstack-config --set /etc/trove/trove.conf DEFAULT log_dir /var/log/trove
openstack-config --set /etc/trove/trove.conf DEFAULT trove_auth_url http://$CONTROLLER_IP:5000/v2.0
openstack-config --set /etc/trove/trove.conf DEFAULT nova_compute_url http://$CONTROLLER_IP:8774/v2
openstack-config --set /etc/trove/trove.conf DEFAULT cinder_url http://$CONTROLLER_IP:8776/v1
openstack-config --set /etc/trove/trove.conf DEFAULT swift_url http://$CONTROLLER_IP:8080/v1/AUTH_
openstack-config --set /etc/trove/trove.conf DEFAULT sql_connection mysql://trove:$SERVICE_PWD@$CONTROLLER_IP/trove
openstack-config --set /etc/trove/trove.conf DEFAULT notifier_queue_hostname $CONTROLLER_IP
openstack-config --set /etc/trove/trove.conf DEFAULT rpc_backend trove.openstack.common.rpc.impl_kombu
openstack-config --set /etc/trove/trove.conf DEFAULT rabbit_host $CONTROLLER_IP

openstack-config --set /etc/trove/trove-taskmanager.conf DEFAULT log_dir /var/log/trove
openstack-config --set /etc/trove/trove-taskmanager.conf DEFAULT trove_auth_url http://$CONTROLLER_IP:5000/v2.0
openstack-config --set /etc/trove/trove-taskmanager.conf DEFAULT nova_compute_url http://$CONTROLLER_IP:8774/v2
openstack-config --set /etc/trove/trove-taskmanager.conf DEFAULT cinder_url http://$CONTROLLER_IP:8776/v1
openstack-config --set /etc/trove/trove-taskmanager.conf DEFAULT swift_url http://$CONTROLLER_IP:8080/v1/AUTH_
openstack-config --set /etc/trove/trove-taskmanager.conf DEFAULT sql_connection mysql://trove:$SERVICE_PWD@$CONTROLLER_IP/trove
openstack-config --set /etc/trove/trove-taskmanager.conf DEFAULT notifier_queue_hostname $CONTROLLER_IP
openstack-config --set /etc/trove/trove-taskmanager.conf DEFAULT rpc_backend trove.openstack.common.rpc.impl_kombu
openstack-config --set /etc/trove/trove-taskmanager.conf DEFAULT rabbit_host $CONTROLLER_IP

openstack-config --set /etc/trove/trove-conductor.conf DEFAULT log_dir /var/log/trove
openstack-config --set /etc/trove/trove-conductor.conf DEFAULT trove_auth_url http://$CONTROLLER_IP:5000/v2.0
openstack-config --set /etc/trove/trove-conductor.conf DEFAULT nova_compute_url http://$CONTROLLER_IP:8774/v2
openstack-config --set /etc/trove/trove-conductor.conf DEFAULT cinder_url http://$CONTROLLER_IP:8776/v1
openstack-config --set /etc/trove/trove-conductor.conf DEFAULT swift_url http://$CONTROLLER_IP:8080/v1/AUTH_
openstack-config --set /etc/trove/trove-conductor.conf DEFAULT sql_connection mysql://trove:$SERVICE_PWD@$CONTROLLER_IP/trove
openstack-config --set /etc/trove/trove-conductor.conf DEFAULT notifier_queue_hostname $CONTROLLER_IP
openstack-config --set /etc/trove/trove-conductor.conf DEFAULT rpc_backend trove.openstack.common.rpc.impl_kombu
openstack-config --set /etc/trove/trove-conductor.conf DEFAULT rabbit_host $CONTROLLER_IP


# Changes only made to api-paste.ini #############################################################

# create default api-paste file ###################################
cat > /etc/trove/api-paste.ini <<EOF
[composite:trove]
use = call:trove.common.wsgi:versioned_urlmap
/: versions
/v1.0: troveapi

[app:versions]
paste.app_factory = trove.versions:app_factory

[pipeline:troveapi]
pipeline = faultwrapper authtoken authorization contextwrapper ratelimit extensions troveapp
#pipeline = debug extensions troveapp

[filter:extensions]
paste.filter_factory = trove.common.extensions:factory

[filter:authtoken]
auth_uri = http://$CONTROLLER_IP:5000/v2.0
identity_uri = http://$CONTROLLER_IP:35357
admin_user = trove
admin_password = $SERVICE_PWD
admin_tenant_name = service
signing_dir = /var/cache/trove
paste.filter_factory = keystonemiddleware.auth_token:filter_factory
auth_host = $CONTROLLER_IP
auth_port = 35357
auth_protocol = http
# signing_dir is configurable, but the default behavior of the authtoken
# middleware should be sufficient.  It will create a temporary directory
# in the home directory for the user the trove process is running as.
#signing_dir = /var/lib/trove/keystone-signing

[filter:authorization]
paste.filter_factory = trove.common.auth:AuthorizationMiddleware.factory

[filter:contextwrapper]
paste.filter_factory = trove.common.wsgi:ContextMiddleware.factory

[filter:faultwrapper]
paste.filter_factory = trove.common.wsgi:FaultWrapper.factory

[filter:ratelimit]
paste.filter_factory = trove.common.limits:RateLimitingMiddleware.factory

[app:troveapp]
paste.app_factory = trove.common.api:app_factory

#Add this filter to log request and response for debugging
[filter:debug]
paste.filter_factory = trove.common.wsgi:Debug
EOF

openstack-config --set /etc/trove/apt-paste.ini filter:authtoken auth_uri http://$CONTROLLER_IP:5000/v2.0
openstack-config --set /etc/trove/apt-paste.ini filter:authtoken identity_uri http://$CONTROLLER_IP:35357
openstack-config --set /etc/trove/apt-paste.ini filter:authtoken admin_user trove
openstack-config --set /etc/trove/apt-paste.ini filter:authtoken admin_password $SERVICE_PWD
openstack-config --set /etc/trove/apt-paste.ini filter:authtoken admin_tenant_name service
openstack-config --set /etc/trove/apt-paste.ini filter:authtoken signing_dir /var/cache/trove

# Changes only made to trove.conf #####################################################################################

openstack-config --set /etc/trove/trove.conf DEFAULT default_datastore mysql
openstack-config --set /etc/trove/trove.conf DEFAULT add_addresses True
openstack-config --set /etc/trove/trove.conf DEFAULT network_label_regex ^NETWORK_LABEL$
openstack-config --set /etc/trove/trove.conf DEFAULT api_paste_config /etc/trove/api-paste.ini

# Changes only made to trove-taskmanager.conf #########################################################################

openstack-config --set /etc/trove/trove-taskmanager.conf DEFAULT nova_proxy_admin_user admin
openstack-config --set /etc/trove/trove-taskmanager.conf DEFAULT nova_proxy_admin_pass $SERVICE_PWD
openstack-config --set /etc/trove/trove-taskmanager.conf DEFAULT nova_proxy_admin_tenant_name service
openstack-config --set /etc/trove/trove-taskmanager.conf DEFAULT taskmanager_manager trove.taskmanager.manager.Manager

# Changes only made to trove-guestagent.conf ##########################################################################

openstack-config --set /etc/trove/trove-guestagent.conf DEFAULT rabbit_host $CONTROLLER_IP
openstack-config --set /etc/trove/trove-guestagent.conf DEFAULT nova_proxy_admin_user admin
openstack-config --set /etc/trove/trove-guestagent.conf DEFAULT nova_proxy_admin_pass $SERVICE_PWD
openstack-config --set /etc/trove/trove-guestagent.conf DEFAULT nova_proxy_admin_tenant_name service
openstack-config --set /etc/trove/trove-guestagent.conf DEFAULT trove_auth_url http://$CONTROLLER_IP:35357/v2.0


# initialize the database #######

su -s /bin/sh -c "trove-manage db_sync" trove

# create datastore #######

su -s /bin/sh -c "trove-manage datastore_update mysql ''" trove

mkdir -pv /var/cache/trove
chown -R trove:trove /var/cache/trove

# Finally enable services on start up and run them ###################################################################

systemctl enable openstack-trove-api.service openstack-trove-taskmanager.service openstack-trove-conductor.service
systemctl start openstack-trove-api.service openstack-trove-taskmanager.service openstack-trove-conductor.service
