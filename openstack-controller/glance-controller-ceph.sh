#RBD config for CEPH

openstack-config --set /etc/glance/glance-api.conf DEFAULT default_store rbd
openstack-config --set /etc/glance/glance-api.conf DEFAULT show_image_direct_url True
openstack-config --set /etc/glance/glance-api.conf paste_deploy flavor keystone
openstack-config --set /etc/glance/glance-api.conf glance_store stores rbd
openstack-config --set /etc/glance/glance-api.conf glance_store rbd_store_pool images
openstack-config --set /etc/glance/glance-api.conf glance_store rbd_store_user glance
openstack-config --set /etc/glance/glance-api.conf glance_store rbd_store_ceph_conf /etc/ceph/ceph.conf
openstack-config --set /etc/glance/glance-api.conf glance_store rbd_store_chunk_size 8


