#!/bin/sh

unset SSH_AUTH_SOCK

rm -rf ~/src ~/venvs /etc/kayobe /etc/kolla /opt/kayobe /etc/contrail/
pdsh -g head,compute 'docker ps -a -q|xargs docker rm -f -v'
pdsh -g head,compute 'docker volume prune -f'
pdsh -g head,compute 'docker image ls -q|xargs docker image rm -f'
pdsh -g head,compute 'rm -rf /opt/kayobe/ /etc/kolla/ /etc/contrail/'
pdsh -g compute 'rm -f /var/run/libvirt/libvirt-sock'
pdsh -g compute 'pkill -9 -f qemu-kvm'