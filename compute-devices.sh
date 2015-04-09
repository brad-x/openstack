#!/bin/bash
cd ${LXC_ROOTFS_MOUNT}/dev
mknod kvm c 10 232
chown root:kvm kvm
chmod 660 kvm
mkdir net
mknod net/tun c 10 200
chmod 666 net/tun

