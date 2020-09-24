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
on-compute 'rm -f /etc/sysconfig/network-scripts/ifcfg-p-*'
on-all 'ln -fs /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf'

rm -rf src venvs /etc/kayobe /etc/kolla /opt/kayobe /etc/contrail/
on-all 'docker ps -q|while read i; do docker rm -f -v $i; done'
on-all 'docker volume prune -f'
on-all 'docker image ls -q|xargs docker image rm -f'
on-all 'rm -rf /opt/kayobe/ /etc/contrail/'
on-compute 'rm -f /var/run/libvirt/libvirt-sock'


cat > /tmp/daemon.json << \EOF
{
    "insecure-registries": [
        "build:5000"
    ],
    "live-restore": true,
    "log-opts": {
        "max-file": "5",
        "max-size": "50m"
    },
    "mtu": 1500,
    "storage-driver": "overlay",
    "storage-opts": []
}
EOF
cp-all /tmp/daemon.json /etc/docker/daemon.json

on-compute 'reboot'

#on-compute 'rm -f /etc/sysconfig/network-scripts/{ifcfg-p-*,ifcfg-vhost*}; reboot'
