#!/bin/sh
set -e

. ~/kayobe.venv

# speed up disk writes for testing only
pdsh -g head,compute 'echo "write back" > /sys/class/block/sda/queue/write_cache' ||:

echo "FIXME2: Change iface name to eth0, otherwise kolla-ansible will fail to find host ip"
sed -i "s/common_interface: .*/common_interface: eth0/" "$KAYOBE_CONFIG_PATH/inventory/group_vars/compute/network-interfaces"

kayobe overcloud host configure

pdsh -g compute ip r r default via 172.16.0.1 dev vhost0 ||:

echo "FIXME3: should be installed by 'kayobe overcloud host configure'"
pdsh -g head,compute '/opt/kayobe/venvs/kolla-ansible/bin/pip install docker-compose'
