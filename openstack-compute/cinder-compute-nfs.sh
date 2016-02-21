# NFS Config

echo "192.168.0.6:/export/openstack" > /etc/cinder/nfsshares

openstack-config --set /etc/cinder/cinder.conf DEFAULT volume_driver cinder.volume.drivers.nfs.NfsDriver
openstack-config --set /etc/cinder/cinder.conf DEFAULT nfs_shares_config /etc/cinder/nfsshares

openstack-config --set /etc/nova/nova.conf libvirt disk_cachemodes "network=writeback,file=writeback,block=writeback"
