#!/bin/sh
. ./.config.sh
. ./common/functions.sh

# on the kayobe control host
cat > /tmp/ifcfg-eth0 << EOF
DEVICE=eth0
BOOTPROTO=none
ONBOOT=yes
NM_CONTROLLED=no
EOF
cat > /tmp/ifcfg-vhost0 << EOF
DEVICE=vhost0
BOOTPROTO=none
ONBOOT=yes
TYPE=kernel
NM_CONTROLLED=NO
BIND_INT=eth0
EOF
cat > /tmp/80-vhost.network << EOF
[Match]
Name=vhost*
[Network]
DHCP=yes
LLMNR=no
MulticastDNS=no
EOF
cp-compute /tmp/ifcfg-eth0 /etc/sysconfig/network-scripts/ifcfg-eth0
cp-compute /tmp/ifcfg-vhost0 /etc/sysconfig/network-scripts/ifcfg-vhost0
on-compute rm -f /etc/systemd/network/*
cp-compute /tmp/80-vhost.network /etc/systemd/network/80-vhost-dhcp.network
on-all 'ln -fs /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf'
on-compute 'rm -f /etc/sysconfig/network-scripts/ifcfg-p-*'

rm -rf /etc/contrail/
on-all 'docker ps|awk "NR!=1 && \$2~/^build/ {print \$1}"|while read i; do docker rm -f -v $i; done'
on-all 'rm -rf /etc/contrail/'
on-compute 'rm -f /var/run/libvirt/libvirt-sock'

on-compute 'reboot'

#cp-compute /tmp/ifcfg-eth0 /etc/sysconfig/network-scripts/ifcfg-eth0
#on-compute 'rm -f /etc/sysconfig/network-scripts/{ifcfg-p-*,ifcfg-vhost*};'
