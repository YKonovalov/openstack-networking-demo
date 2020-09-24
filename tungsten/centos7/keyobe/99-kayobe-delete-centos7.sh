#!/bin/bash
# on the kayobe control host
cat > /tmp/ifcfg-eth0 << EOF
DEVICE=eth0
BOOTPROTO=dhcp
ONBOOT=yes
NM_CONTROLLED=no
EOF
rm -rf src venvs /etc/kayobe /etc/kolla /opt/kayobe /etc/contrail/
pdcp -w kolla[1-3] /tmp/ifcfg-eth0 /etc/sysconfig/network-scripts/ifcfg-eth0
pdsh -w kolla,kolla[1-3] 'docker ps -q|while read i; do docker rm -f -v $i; done; docker volume prune -f; rm -rf /opt/kayobe/ /etc/contrail/'
pdsh -w kolla[1-3] 'rm -f /var/run/libvirt/libvirt-sock'

pdcp -w kolla[1-3] /tmp/ifcfg-eth0 /etc/sysconfig/network-scripts/ifcfg-eth0
pdsh -w kolla[1-3] 'rm -f /etc/sysconfig/network-scripts/{ifcfg-p-*,ifcfg-vhost*}; reboot'
