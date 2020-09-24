cat > /etc/yum.repos.d/calico.repo <<EOF
[calico]
name=Calico Repository
baseurl=https://binaries.projectcalico.org/rpm/calico-3.13/
enabled=1
skip_if_unavailable=0
gpgcheck=1
gpgkey=https://binaries.projectcalico.org/rpm/calico-3.13/key
priority=97
EOF

# control
sed -e "/^service_plugins/ d" \
    -e "s/^core_plugin.*/core_plugin=calico/" \
    -e "$ a [calico]\netcd_host = 172.31.0.27" /etc/neutron/neutron.conf

yum install -y calico-control
systemctl restart neutron-server

# compute
alias on-all='pdsh -w chead,calico[1-3]'
alias on-head='pdsh -w chead'

pdsh -w chead,calico[1-3] systemctl stop neutron-openvswitch-agent
pdsh -w chead,calico[1-3] systemctl disable neutron-openvswitch-agent

pdsh -w chead,calico[1-3] systemctl stop openvswitch
pdsh -w chead,calico[1-3] systemctl disable openvswitch
pdsh -w chead '. keystonerc_admin; neutron agent-list|sed -n "s/^| \([0-9a-f-]\+\).*/\1/p"|while read id; do neutron agent-delete $id; done'

pdsh -w calico[1-3] yum install -y openstack-neutron
pdsh -w calico[1-3] sed -i 's/# \(lock_path.*\)/\1/' /etc/neutron/neutron.conf

pdsh -w chead,calico[1-3] systemctl stop neutron-dhcp-agent
pdsh -w chead,calico[1-3] systemctl disable neutron-dhcp-agent
pdsh -w calico[1-3] yum install -y calico-dhcp-agent

pdsh -w chead,calico[1-3] systemctl stop neutron-l3-agent
pdsh -w chead,calico[1-3] systemctl disable neutron-l3-agent

pdsh -w calico[1-3] yum install -y openstack-nova-api
pdsh -w calico[1-3] systemctl enable openstack-nova-metadata-api
pdsh -w calico[1-3] systemctl restart openstack-nova-metadata-api

pdsh -w calico[1-3] 'yum --enablerepo epel install -y bird bird6'
pdsh -w calico[1-3] yum install -y calico-compute
pdsh -w calico[1-3] systemctl restart openstack-nova-compute

pdsh -w calico[1-3] 'calico-gen-bird-mesh-conf.sh $(ip -o r g 1|sed "s/.* src \([^[:blank:]]\+\).*/\1/") 65001 $(grep calico /etc/hosts |grep -v `hostname`|awk "{print \$1}")'

cat > /etc/calico/felix.cfg <<EOF
[global]
DatastoreType = etcdv3
EtcdAddr = 172.31.0.27:2379
EOF

pdcp -w calico[1-3] /etc/calico/felix.cfg /etc/calico/felix.cfg
pdsh -w calico[1-3] systemctl restart calico-felix.service


cat > /etc/calico/calicoctl.cfg << \EOF
apiVersion: projectcalico.org/v3
kind: CalicoAPIConfig
metadata:
spec:
  datastoreType: "etcdv3"
  etcdEndpoints: "http://172.31.0.27:2379"
EOF

pdsh -w chead 'mkdir -p /etc/calico'
pdcp -w chead,calico[1-3] /etc/calico/calicoctl.cfg /etc/calico/calicoctl.cfg
curl -O -L  https://github.com/projectcalico/calicoctl/releases/download/v3.13.3/calicoctl
install -m 755 calicoctl /usr/local/bin/
pdcp -w chead,calico[1-3] /usr/local/bin/calicoctl /usr/local/bin/calicoctl

calicoctl get felixconfig default -o yaml --export
calicoctl get ippool

for host in calico1 calico2 calico3; do
calicoctl create -f - <<EOF
- apiVersion: projectcalico.org/v3
  kind: Node
  metadata:
    name: $host
EOF
done
