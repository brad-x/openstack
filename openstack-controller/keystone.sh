#!/bin/bash

source ./config

# Install keystone

yum -y install openstack-keystone python-keystoneclient

# Create databases for keystone 
mysql -u root -p${SQL_PWD} -e "CREATE DATABASE keystone;"
mysql -u root -p${SQL_PWD} -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$SERVICE_PWD';"
mysql -u root -p${SQL_PWD} -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$SERVICE_PWD';"
mysql -u root -p${SQL_PWD} -e "FLUSH PRIVILEGES;"

# Set up /etc/keystone.conf
openstack-config --set /etc/keystone/keystone.conf DEFAULT admin_token $ADMIN_TOKEN
openstack-config --set /etc/keystone/keystone.conf database connection mysql://keystone:${SERVICE_PWD}@${CONTROLLER_IP}/keystone
openstack-config --set /etc/keystone/keystone.conf token provider keystone.token.providers.uuid.Provider
openstack-config --set /etc/keystone/keystone.conf token driver keystone.token.persistence.backends.sql.Token

# inish keystone setup
keystone-manage pki_setup --keystone-user keystone --keystone-group keystone
chown -R keystone:keystone /var/log/keystone
chown -R keystone:keystone /etc/keystone/ssl
chmod -R o-rwx /etc/keystone/ssl
su -s /bin/sh -c "keystone-manage db_sync" keystone

#start keystone
systemctl enable openstack-keystone.service
systemctl start openstack-keystone.service

#schedule token purge
(crontab -l -u keystone 2>&1 | grep -q token_flush) || \
  echo '@hourly /usr/bin/keystone-manage token_flush >/var/log/keystone/keystone-tokenflush.log 2>&1' \
  >> /var/spool/cron/keystone
  
#create users and tenants
export OS_SERVICE_TOKEN=$ADMIN_TOKEN
export OS_SERVICE_ENDPOINT=http://$CONTROLLER_IP:35357/v2.0
keystone tenant-create --name admin --description "Admin Tenant"
keystone user-create --name admin --pass $ADMIN_PWD
keystone role-create --name admin
keystone user-role-add --tenant admin --user admin --role admin
keystone role-create --name _member_
keystone user-role-add --tenant admin --user admin --role _member_
keystone tenant-create --name demo --description "Demo Tenant"
keystone user-create --name demo --pass password
keystone user-role-add --tenant demo --user demo --role _member_
keystone tenant-create --name service --description "Service Tenant"
keystone service-create --name keystone --type identity \
  --description "OpenStack Identity"
keystone endpoint-create \
  --service-id $(keystone service-list | awk '/ identity / {print $2}') \
  --publicurl http://$CONTROLLER_IP:5000/v2.0 \
  --internalurl http://$CONTROLLER_IP:5000/v2.0 \
  --adminurl http://$CONTROLLER_IP:35357/v2.0 \
  --region $REGION
unset OS_SERVICE_TOKEN OS_SERVICE_ENDPOINT

#create credentials file
echo "export OS_TENANT_NAME=admin" > creds
echo "export OS_USERNAME=admin" >> creds
echo "export OS_PASSWORD=$ADMIN_PWD" >> creds
echo "export OS_AUTH_URL=http://$CONTROLLER_IP:35357/v2.0" >> creds
