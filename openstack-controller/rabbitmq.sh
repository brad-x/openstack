#!/bin/sh

source ./config

#install messaging service
yum -y install rabbitmq-server
systemctl enable rabbitmq-server.service
systemctl start rabbitmq-server.service

mkdir -pv /etc/openstack-uncharted/

touch /etc/openstack-uncharted/rabbitmq-setup-done

