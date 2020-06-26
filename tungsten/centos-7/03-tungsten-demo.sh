#!/bin/sh -e

. keystonerc_admin

openstack image show cirros2 >/dev/null 2>&1 || (
  curl -OL --progress http://download.cirros-cloud.net/0.5.1/cirros-0.5.1-x86_64-disk.img
  openstack image create cirros2 --disk-format qcow2 --public --container-format bare --file cirros-0.5.1-x86_64-disk.img
)

while read net cidr; do
  netid="$(openstack network create --share $net -c id -f value)"; [ -n "$netid" ]
  openstack subnet create --network $net --ip-version 4 --subnet-range $cidr $net-v4

  for name in a b c; do
    openstack server create --flavor m1.tiny --image cirros2 --network=$netid $net-$name
  done
done << EOF
pub-a 192.168.168.0/24
pub-b 192.168.169.0/24
pub-c 192.168.170.0/24
pub-d 192.168.100.0/24"
EOF
