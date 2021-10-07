#!/bin/sh

unset SSH_AUTH_SOCK

rm -rf ~/src ~/venvs
pdsh -a 'docker ps -a -q|xargs docker rm -f -v'
pdsh -a 'docker volume prune -f'
pdsh -a 'docker image ls -q|xargs docker image rm -f'
pdsh -a 'rm -rf /opt/kayobe/ /etc/kolla/ /etc/contrail/'
pdsh -g compute 'rm -f /var/run/libvirt/libvirt-sock'
pdsh -g compute 'pkill -9 -f qemu-kvm'
