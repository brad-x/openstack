# iSCSI Cinder

cinder storage node
pvcreate /dev/sdb
vgcreate cinder-volumes /dev/sdb

openstack-config --set /etc/cinder/cinder.conf DEFAULT iscsi_helper lioadm

systemctl enable target.service
systemctl start target.service

