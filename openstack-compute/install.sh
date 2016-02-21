#!/bin/bash

storage=$1

if [ -z $storage ]
then
        echo "No storage type specified. Specify one of ceph, nfs or iscsi to proceed. Make sure these are configured!"
        exit 1
fi

sh ./common.sh

sh ./ipsetup.sh

# Install nova compute
sh ./nova-compute.sh

# Install neutron agents
sh ./neutron-compute.sh

# Install cinder for compute/storage
sh ./cinder-compute.sh
sh ./cinder-compute-$storage.sh
