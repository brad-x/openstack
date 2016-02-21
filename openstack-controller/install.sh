#!/bin/bash

sh ./common.sh

sh ./ipsetup.sh

# Install MariaDB
sh ./mariadb.sh

# Install RabbitMQ
sh ./rabbitmq.sh

# Install dashboard
sh ./horizon-dashboard.sh 

# Install keystone
# Create databases for keystone 
# Create credentials file
sh ./keystone.sh

# Install glance
# Create databases for glance
# Create keystone entries for glance
sh ./glance-controller.sh

# Install the nova controller
# Create databases for nova
# Create keystone entries for nova
sh ./nova-controller.sh

# Install neutron
# Create databases for neutron 
# Create keystone entries for neutron
sh ./neutron-controller.sh

# Install cinder controller
# Create databases for cinder
# Create keystone entries for cinder
sh ./cinder-controller.sh

# Install heat controller
# Create databases for heat
# Create keystone entries for heat
sh ./heat-controller.sh
