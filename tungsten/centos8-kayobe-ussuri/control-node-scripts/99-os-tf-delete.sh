#!/bin/sh
. ./config.sh
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
ONBOOT=no
TYPE=kernel
NM_CONTROLLED=NO
BIND_INT=eth0
EOF

cp-compute /tmp/ifcfg-eth0 /etc/sysconfig/network-scripts/ifcfg-eth0
cp-compute /tmp/ifcfg-vhost0 /etc/sysconfig/network-scripts/ifcfg-vhost0

on-compute systemctl disable networkd-disable-ip-on-eth0-when-vhost0.service
on-compute rm -f /etc/systemd/system/networkd-disable-ip-on-eth0-when-vhost0.service

rm -rf src venvs /etc/kayobe /etc/kolla /opt/kayobe /etc/contrail/
on-all 'docker ps -q|xargs docker rm -f -v'
on-all 'docker volume prune -f'
on-all 'docker image ls -q|xargs docker image rm -f'
on-all 'rm -rf /opt/kayobe/ /etc/kolla/ /etc/contrail/'
on-compute 'rm -f /var/run/libvirt/libvirt-sock'

on-compute 'reboot'
