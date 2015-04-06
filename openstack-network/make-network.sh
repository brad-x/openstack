#!/bin/bash
source ./creds

neutron net-create ext-net --shared --router:external True \
--provider:physical_network external --provider:network_type flat

neutron subnet-create ext-net --name ext-subnet \
--allocation-pool start=192.168.10.1,end=192.168.255.254 \
--disable-dhcp --gateway 192.168.0.1 192.168.0.0/16

neutron net-create internal-net

neutron subnet-create internal-net --name internal-subnet \
--dns-nameserver 192.168.0.5 \
--gateway 10.0.1.1 10.0.1.0/24

neutron router-create internal-router

neutron router-interface-add internal-router internal-subnet

neutron router-gateway-set internal-router ext-net
