#!/bin/sh
set -e

. ~/kayobe.venv


# speed up disk writes for testing only
pdsh -g head,compute 'echo "write back" > /sys/class/block/sda/queue/write_cache' ||:

chost="$(nodeattr -n control|head -1)"
iface="$(nodeattr -v $chost iface)"
iface="${iface:-eth0}"
echo "FIXME2: Change iface name to $iface, otherwise kolla-ansible will fail to find host ip"
sed -i "s/common_interface: .*/common_interface: $iface/" "$KAYOBE_CONFIG_PATH/inventory/group_vars/compute/network-interfaces"

pdsh -g compute 'ip -j r s default|jq -r ".[]|.dev=\"vhost0\"|[.dst,\"via\",.gateway,\"dev\",.dev]|@tsv"|xargs ip r r' ||:

kayobe overcloud host configure

echo "If we are running after tf vrouter already installed we should move default route back to vhost0"
pdsh -g compute 'ip -j r s default|jq -r ".[]|.dev=\"vhost0\"|[.dst,\"via\",.gateway,\"dev\",.dev]|@tsv"|xargs ip r r' ||:
