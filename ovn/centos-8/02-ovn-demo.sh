#!/bin/sh -e

net=ovn
cidr=10.1.0.0/16
gw=10.1.0.1

openstack image show cirros2 >/dev/null 2>&1 || (
  curl -OL --progress http://download.cirros-cloud.net/0.5.1/cirros-0.5.1-x86_64-disk.img
  openstack image create cirros2 --disk-format qcow2 --public --container-format bare --file cirros-0.5.1-x86_64-disk.img
)

netid="$(openstack network create --share $net -c id -f value)"; [ -n "$netid" ]
openstack subnet create --network $net --ip-version 4 --gateway $gw --subnet-range $cidr $net-v4

for name in a b c d e; do
  openstack server create --flavor m1.tiny --image cirros2 --network=$netid $net-$name
done
