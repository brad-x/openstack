#!/bin/bash
source ./creds

neutron net-create ext-net --shared --router:external True \
--provider:physical_network external --provider:network_type flat

neutron subnet-create ext-net --name ext-subnet \
--allocation-pool start=192.168.100.200,end=192.168.100.220 \
--disable-dhcp --gateway 192.168.100.1 192.168.100.0/24

neutron net-create demo-net

neutron subnet-create demo-net --name demo-subnet \
--dns-nameserver 192.168.0.5 \
--gateway 10.0.1.1 10.0.1.0/24

neutron router-create demo-router

neutron router-interface-add demo-router demo-subnet

neutron router-gateway-set demo-router ext-net
