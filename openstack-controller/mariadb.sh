#!/bin/bash

source ./config

# Install database server
yum -y install mariadb mariadb-server MySQL-python

#edit /etc/my.cnf
sed -i.bak "10i\\
bind-address = 0.0.0.0\n\
default-storage-engine = innodb\n\
innodb_file_per_table\n\
collation-server = utf8_general_ci\n\
init-connect = 'SET NAMES utf8'\n\
character-set-server = utf8\n\
open_files_limit = 8192\n\
max_connections = 8192\n\
" /etc/my.cnf

#start database server
systemctl enable mariadb.service
systemctl start mariadb.service

echo 'now run through the mysql_secure_installation'
#mysql_secure_installation
mysql -u root -e "DROP DATABASE test;"
mysql -u root -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'"
mysql -u root -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql -u root -e "DELETE FROM mysql.user WHERE User='';"
mysql -u root -e "UPDATE mysql.user SET Password=PASSWORD('${SQL_PWD}') WHERE User='root';"
mysql -u root -e "FLUSH PRIVILEGES;"

mkdir -pv /etc/openstack-uncharted/

touch /etc/openstack-uncharted/mariadb-setup-done

