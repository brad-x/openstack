# create host aggregate and add compute nodes to it

nova aggregate-create "Uncharted Toronto Office"
nova aggregate-add-host 1 openstack-compute-node02
nova aggregate-add-host 1 openstack-compute-node01


