#!/bin/bash
source ./creds

neutron net-create ext-net --shared --router:external True \
--provider:physical_network external --provider:network_type flat

neutron subnet-create ext-net --name ext-subnet \
--allocation-pool start=10.64.4.0,end=10.64.5.255 \
--disable-dhcp --gateway 10.64.0.1 10.64.0.0/16

neutron net-create internal-net

neutron subnet-create internal-net --name internal-subnet \
--dns-nameserver 10.64.0.1 \
--gateway 10.1.0.1 10.1.0.0/16

neutron router-create internal-router

neutron router-interface-add internal-router internal-subnet

neutron router-gateway-set internal-router ext-net
