#!/bin/bash
# on the kayobe control host
rm -rf src venvs /etc/kayobe /etc/kolla /opt/kayobe
pdsh -w kolla,kolla[1-3] 'docker ps -q|while read i; do docker rm -f -v $i; done; docker volume prune -f; rm -rf /opt/kayobe/'
pdsh -w kolla[1-3] 'rm -f /var/run/libvirt/libvirt-sock'
pdsh -w kolla[1-3] rm -f /etc/sysconfig/network-scripts/ifcfg-vhost0
