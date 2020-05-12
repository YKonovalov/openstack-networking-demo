#!/bin/sh
head_ip="$(ip -o r g 1|sed "s/.* src \([^[:blank:]]\+\).*/\1/")" #"
comp_ip="$(grep calico /etc/hosts |grep -v `hostname`|awk "{print \$1}")"
alias all='pdsh -w chead,calico[1-3]'
alias head='pdsh -w chead'
alias comp='pdsh -w calico[1-3]'

alias allcp='pdcp -w chead,calico[1-3]'
alias compcp='pdcp -w calico[1-3]'

etcdClear(){
  ETCDCTL_API=3 etcdctl --endpoints http://$head_ip:2379 del "" --from-key=true
}

# build rpms
dnf -y install rpm-build mock
rpm -i https://binaries.projectcalico.org/rpm/calico-3.14/src/networking-calico-3.14.0-1.el7.src.rpm \
       https://binaries.projectcalico.org/rpm/calico-3.14/src/python-etcd3gw-0.2.4.1.5a3157a-1.el7.src.rpm \
       https://binaries.projectcalico.org/rpm/calico-3.14/src/felix-3.14.0-1.el7.src.rpm \
       https://binaries.projectcalico.org/rpm/calico-3.14/src/dnsmasq-2.79_calico1-2.el7.2.src.rpm

cp patches/networking-calico-3.14.0-python3-openstack-train.patch \
   patches/felix-3.14.0-bird-template-ipv4.patch \
   rpmbuild/SOURCES/

cat patches/felix.spec.patch \
    patches/networking-calico.spec.patch \
    patches/python-etcd3gw.spec.patch | patch -p1 -d rpmbuild/SPECS

rpmbuild -bs --nodebuginfo \
         rpmbuild/SPECS/python-etcd3gw.spec \
         rpmbuild/SPECS/networking-calico.spec \
         rpmbuild/SPECS/felix.spec \
         rpmbuild/SPECS/dnsmasq.spec
mock --resultdir /root/rpms \
     rpmbuild/SRPMS/python-etcd3gw-0.2.4.1.5a3157a-1.el8.src.rpm \
     rpmbuild/SRPMS/networking-calico-3.14.0-1.el8.src.rpm \
     rpmbuild/SRPMS/felix-3.14.0-1.el8.src.rpm \
     rpmbuild/SRPMS/dnsmasq-2.79_calico1-2.el8.2.src.rpm
allcp /root/rpms/* /root/
all rm -f /root/*.src.rpm /root/*debug*.rpm

#install

head 'dnf -y install etcd \
        ./calico-control*.rpm \
        ./python3-etcd3gw*.rpm \
        ./networking-calico*.rpm'
comp 'dnf -y install openstack-neutron openstack-nova-api \
        ./calico-common*.rpm \
        ./calico-compute*.rpm \
        ./calico-felix*.rpm \
        ./calico-dhcp-agent*.rpm \
        ./networking-calico*.rpm \
        ./python3-etcd3gw*.rpm \
        ./dnsmasq*.rpm \
        ./dnsmasq-utils-2*.rpm'
comp 'dnf -y --enablerepo epel install bird bird6'

curl -O -L  https://github.com/projectcalico/calicoctl/releases/download/v3.13.3/calicoctl
install -m 755 calicoctl /usr/local/bin/
allcp /usr/local/bin/calicoctl /usr/local/bin/calicoctl

curl -LO https://dl.google.com/go/go1.14.2.linux-amd64.tar.gz
tar -C /usr/local -xzf go1.14.2.linux-amd64.tar.gz
PATH=$PATH:/usr/local/go/bin
mkdir -p /root/go/src/github.com/projectcalico
(
 cd /root/go/src/github.com/projectcalico
 git clone https://github.com/projectcalico/node.git
 cd node/cmd/calico-node
 go build
 install -m 755 calico-node /usr/local/bin/
)
compcp /usr/local/bin/calico-node /usr/local/bin/calico-node


# configure

sed -i "s/localhost:2379/$head_ip:2379/" /etc/etcd/etcd.conf

all 'sed -i -e "/^service_plugins/ d" \
            -e "s/^core_plugin.*/core_plugin=calico/" \
            -e "$ a [calico]\netcd_host = '$head_ip'" \
         /etc/neutron/neutron.conf'
comp 'sed -i "s/# \(lock_path.*\)/\1/" /etc/neutron/neutron.conf'

head 'mkdir -p /etc/calico'
cat > /etc/calico/felix.cfg <<EOF
[global]
DatastoreType = etcdv3
EtcdAddr = $head_ip:2379
EOF
compcp /etc/calico/felix.cfg /etc/calico/felix.cfg
comp 'sed -i "$ a FelixHostname = $(awk -F= -v h=host "\$1==h {print \$2}" /etc/nova/nova.conf)" /etc/calico/felix.cfg'
comp 'hostnamectl set-hostname $(awk -F= -v h=host "\$1==h {print \$2}" /etc/nova/nova.conf)'

cat > /etc/calico/calicoctl.cfg << EOF
apiVersion: projectcalico.org/v3
kind: CalicoAPIConfig
metadata:
spec:
  datastoreType: "etcdv3"
  etcdEndpoints: "http://$head_ip:2379"
EOF

allcp /etc/calico/calicoctl.cfg /etc/calico/calicoctl.cfg

#comp 'calico-gen-bird-mesh-conf.sh $(ip -o r g 1|sed "s/.* src \([^[:blank:]]\+\).*/\1/") 65001 $(grep calico /etc/hosts |grep -v `hostname`|awk "{print \$1}")' #"
#comp 'sed -i "s/\(protocol bgp .\)\(172.31.0.\)\(.*\)/\1cal\3/" /etc/bird.conf'
compcp genbird.sh /usr/local/bin/
comp genbird.sh

cat > /etc/calico/calico.env << EOF
ETCD_ENDPOINTS=http://$head_ip:2379
IP_AUTODETECTION_METHOD='interface=eth.*'
CALICO_NETWORKING_BACKEND=vxlan
CLUSTER_TYPE=openstack
FELIX_IPV6SUPPORT=False
EOF
compcp /etc/calico/calico.env /etc/calico/calico.env
comp 'sed -i "$ a NODENAME=$(awk -F= -v h=host "\$1==h {print \$2}" /etc/nova/nova.conf)" /etc/calico/calico.env'

cat > /etc/systemd/system/calico-node.service << \EOF
[Unit]
Description=Calico Node agent
After=syslog.target network.target

[Service]
User=root
EnvironmentFile=/etc/calico/calico.env
ExecStartPre=/usr/bin/mkdir -p /var/run/calico
ExecStartPre=/usr/local/bin/calico-node -startup
ExecStart=/usr/local/bin/calico-node -allocate-tunnel-addrs
KillMode=process
Restart=on-failure
LimitNOFILE=32000

[Install]
WantedBy=multi-user.target
EOF

compcp /etc/systemd/system/calico-node.service /etc/systemd/system/calico-node.service
comp systemctl enable calico-node


# switch to calico
# alias sysls="systemctl -t service --state running --no-pager --no-legend"

all systemctl stop iptables

all systemctl stop ovn-controller.service
all systemctl disable ovn-controller.service

all systemctl stop ovs-vswitchd.service
all systemctl disable ovs-vswitchd.service

all systemctl stop ovsdb-server.service
all systemctl disable ovsdb-server.service

head systemctl restart etcd
head systemctl restart neutron-server
head '. keystonerc_admin; neutron agent-list|sed -n "s/^| \([0-9a-f-]\+\).*/\1/p"|while read id; do neutron agent-delete $id; done'

comp systemctl enable openstack-nova-metadata-api
comp systemctl restart openstack-nova-metadata-api
comp systemctl restart openstack-nova-compute
comp systemctl restart calico-felix.service
comp systemctl restart calico-dhcp-agent.service
comp systemctl restart calico-node

calicoctl get felixconfig default -o yaml --export
calicoctl get ippool

ip link add vxlan.calico type vxlan id 12 dev eth0
ip link set vxlan.calico up


A='{"kind": "WorkloadEndpoint", "apiVersion": "projectcalico.org/v3", "metadata": {"name": "calico2.local-openstack-b1bf802a--5849--4caa--824a--a4bcd92a0b64-689fac39--4c26--4901--a746--f1010fa3857e", "namespace": "openstack", "creationTimestamp": "2020-05-10T14:24:14Z", "uid": "6c0a9347-f06b-4571-a3a0-357778e5b1d0", "annotations": {"openstack.projectcalico.org/network-id": "285a957f-8d43-4a32-9bf8-01254868f691"}, "labels": {"sg.projectcalico.org/openstack-6e5abc36-fb4c-4903-a4ef-b7c847aad1fa": "default", "sg-name.projectcalico.org/openstack-default": "6e5abc36-fb4c-4903-a4ef-b7c847aad1fa", "projectcalico.org/namespace": "openstack", "projectcalico.org/orchestrator": "openstack", "projectcalico.org/openstack-project-id": "d09d55c4ba3a41f0bbd5e4d9bec04adf", "projectcalico.org/openstack-project-name": "admin", "projectcalico.org/openstack-project-parent-id": "default"}}, "spec": {"orchestrator": "openstack", "workload": "b1bf802a-5849-4caa-824a-a4bcd92a0b64", "node": "calico2.local", "endpoint": "689fac39-4c26-4901-a746-f1010fa3857e", "interfaceName": "tap689fac39-4c", "mac": "fa:16:3e:b7:48:ad", "ipv4Gateway": "10.1.0.1", "ipNetworks": ["10.1.1.214/32"], "allowedIps": []}}'
echo $A|jq '.'|python3 -c 'import sys, yaml, json; yaml.dump(json.load(sys.stdin), sys.stdout)'
