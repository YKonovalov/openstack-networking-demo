#!/bin/sh -e

net=vxlan
cidr=10.3.0.0/16
gw=10.3.0.1

cat > /tmp/ippool-$net.yaml <<EOF
apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
  name: $net
spec:
  cidr: $cidr
  vxlanMode: Always
  natOutgoing: false
EOF

calicoctl apply --filename=/tmp/ippool-$net.yaml
calicoctl get ippool $net -o yaml

calicoctl get felixconfig default -o yaml --export
calicoctl get ippool

netid="$(openstack network create --share --provider-network-type local $net -c id -f value)"; [ -z "$netid" ]
openstack subnet create --network $net --ip-version 4 --gateway $gw --subnet-range $cidr $net-v4

for name in a b c d e f; do
  openstack server create --flavor m1.tiny --image cirros2 --network=$netid $net-$name
done

(pdsh -w calico[1-3] 'ip -j a s dev vxlan.calico|jq -r ".[]|select(.!={})|[.ifname,.address,(.addr_info[]|select(.family==\"inet\")|.local)]|@tsv"'|sort;
 pdsh -w calico[1-3] 'ip n s dev vxlan.calico'|sort;
 pdsh -w calico[1-3] 'ip r s dev vxlan.calico'|sort)

# due to broken openstack support in encap mode we need to manualy choose ipaddress from calico node pool
# openstack server create --flavor m1.tiny --image cirros2 --availability-zone nova:calico3.local --nic net-id=cb4701c2-d956-44dc-a4fe-a92ad0f95b8a,v4-fixed-ip=10.3.212.130 vxlan-d
