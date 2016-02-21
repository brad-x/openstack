# Packages required for CEPH
yum -y install python-rbd
yum -y install ceph

# Config for RBD/CEPH

openstack-config --set /etc/cinder/cinder.conf DEFAULT volume_driver cinder.volume.drivers.rbd.RBDDriver
openstack-config --set /etc/cinder/cinder.conf DEFAULT rbd_pool volumes
openstack-config --set /etc/cinder/cinder.conf DEFAULT rbd_ceph_conf /etc/ceph/ceph.conf
openstack-config --set /etc/cinder/cinder.conf DEFAULT rbd_flatten_volume_from_snapshot false
openstack-config --set /etc/cinder/cinder.conf DEFAULT rbd_max_clone_depth 5
openstack-config --set /etc/cinder/cinder.conf DEFAULT rbd_store_chunk_size 4
openstack-config --set /etc/cinder/cinder.conf DEFAULT rados_connect_timeout -1
openstack-config --set /etc/cinder/cinder.conf DEFAULT rbd_user cinder
openstack-config --set /etc/cinder/cinder.conf DEFAULT rbd_secret_uuid $RBD_SECRET_UUID
openstack-config --set /etc/cinder/cinder.conf DEFAULT backup_driver cinder.backup.drivers.ceph
openstack-config --set /etc/cinder/cinder.conf DEFAULT backup_ceph_conf /etc/ceph/ceph.conf
openstack-config --set /etc/cinder/cinder.conf DEFAULT backup_ceph_user cinder-backup
openstack-config --set /etc/cinder/cinder.conf DEFAULT backup_ceph_chunk_size 134217728
openstack-config --set /etc/cinder/cinder.conf DEFAULT backup_ceph_pool backups
openstack-config --set /etc/cinder/cinder.conf DEFAULT backup_ceph_stripe_unit 0
openstack-config --set /etc/cinder/cinder.conf DEFAULT backup_ceph_stripe_count 0
openstack-config --set /etc/cinder/cinder.conf DEFAULT restore_discard_excess_bytes true

openstack-config --set /etc/cinder/cinder.conf DEFAULT enabled_backends standard,ssd-pool
openstack-config --set /etc/cinder/cinder.conf DEFAULT scheduler_driver cinder.scheduler.filter_scheduler.FilterScheduler
openstack-config --set /etc/cinder/cinder.conf DEFAULT default_volume_type standard

openstack-config --set /etc/cinder/cinder.conf standard volume_group standard
openstack-config --set /etc/cinder/cinder.conf standard backend_host volumes
openstack-config --set /etc/cinder/cinder.conf standard rbd_user cinder
openstack-config --set /etc/cinder/cinder.conf standard rbd_pool volumes
openstack-config --set /etc/cinder/cinder.conf standard volume_backend_name standard
openstack-config --set /etc/cinder/cinder.conf standard volume_driver cinder.volume.drivers.rbd.RBDDriver
openstack-config --set /etc/cinder/cinder.conf standard rbd_secret_uuid $RBD_SECRET_UUID

openstack-config --set /etc/cinder/cinder.conf ssd-pool volume_group ssd-pool
openstack-config --set /etc/cinder/cinder.conf ssd-pool host volumes
openstack-config --set /etc/cinder/cinder.conf ssd-pool rbd_user cinder
openstack-config --set /etc/cinder/cinder.conf ssd-pool rbd_pool ssd-pool
openstack-config --set /etc/cinder/cinder.conf ssd-pool volume_backend_name ssd-pool
openstack-config --set /etc/cinder/cinder.conf ssd-pool volume_driver cinder.volume.drivers.rbd.RBDDriver
openstack-config --set /etc/cinder/cinder.conf ssd-pool rbd_secret_uuid $RBD_SECRET_UUID

# Ceph keyrings
chown cinder:cinder /etc/ceph/ceph.client.cinder.keyring
chown cinder:cinder /etc/ceph/ceph.client.cinder-backup.keyring
