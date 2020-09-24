#!/bin/sh -e

net=ip
cidr=10.1.0.0/16
gw=10.1.0.1

cat > /tmp/ippool-$net.yaml <<EOF
apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
  name: $net
spec:
  cidr: $cidr
  vxlanMode: Never
  ipipMode: Never
  natOutgoing: true
EOF

calicoctl apply --filename=/tmp/ippool-$net.yaml
calicoctl get ippool $net -o yaml

calicoctl get felixconfig default -o yaml --export
calicoctl get ippool

netid="$(openstack network create --share --provider-network-type local $net -c id -f value)"; [ -z "$netid" ]
openstack subnet create --network $net --ip-version 4 --gateway $gw --subnet-range $cidr $net-v4

for name in a b; do
  openstack server create --flavor m1.tiny --image cirros2 --network=$netid $net-$name
done
