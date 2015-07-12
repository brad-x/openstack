# openstack

Requires a config file in each subdirectory of the following form: 

	# General Information
	CONTROLLER_IP=192.168.100.10
	ADMIN_TOKEN=ADMIN123
	SERVICE_PWD=Service123
	ADMIN_PWD=password
	META_PWD=meta123
	REGION=TorontoOffice
	DHCP_DOMAIN=openstack-tenant.brad-x.net
	DEFAULT_AZ="brad-x-east-1a"

	# Host IP info
	THISHOST_NAME=juno-controller
	THISHOST_IP=192.168.100.10
	THISHOST_NETMASK=255.255.255.0
	THISHOST_GATEWAY=192.168.100.1
	THISHOST_DNS=192.168.100.1
	THISHOST_TUNNEL_IP=10.20.0.10
	THISHOST_TUNNEL_NETMASK=255.255.255.0

