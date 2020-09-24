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

# configure

sed -i "s/localhost:2379/$head_ip:2379/" /etc/etcd/etcd.conf

all 'sed -i -e "/^service_plugins/ d" \
            -e "s/^core_plugin.*/core_plugin=calico/" \
            -e "$ a [calico]\netcd_host = '$head_ip'" \
         /etc/neutron/neutron.conf'
comp 'sed -i "s/# \(lock_path.*\)/\1/" /etc/neutron/neutron.conf'

cat > /etc/calico/calicoctl.cfg << EOF
apiVersion: projectcalico.org/v3
kind: CalicoAPIConfig
metadata:
spec:
  datastoreType: "etcdv3"
  etcdEndpoints: "http://$head_ip:2379"
EOF

allcp /etc/calico/calicoctl.cfg /etc/calico/calicoctl.cfg

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

comp systemctl enable --now openstack-nova-metadata-api
comp systemctl restart openstack-nova-metadata-api
comp systemctl enable  openstack-nova-compute
comp systemctl restart openstack-nova-compute
comp systemctl enable  calico-dhcp-agent.service
comp systemctl restart calico-dhcp-agent.service

# for ip or vxlan encap calico-node+confd+felix combo is required
comp systemctl disable --now calico-felix.service
comp dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
comp dnf -y install docker-ce --nobest
comp dnf -y install containerd.io
comp systemctl enable --now docker

comp systemctl stop calico-felix.service
comp calicoctl node run
comp calicoctl node status

# hack to restore felix functions as a neutron agent
sleep 3
ETCDCTL_API=3 etcdctl --endpoints http://$head_ip:2379 del /calico/resources/v3/projectcalico.org/felixconfigurations/default

# allow all communications
cat > pol.yaml <<\EOF
apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: allow-all
spec:
  selector: all()
  types:
  - Ingress
  - Egress
  ingress:
  - action: Allow
  egress:
  - action: Allow
EOF
calicoctl apply --filename=pol.yaml

MODS="
arptable_filter
ebtable_broute
ebtable_filter
ebtable_nat
ip6table_filter
ip6table_mangle
ip6table_nat
ip6table_raw
ip6table_security
iptable_filter
iptable_mangle
iptable_nat
iptable_raw
iptable_security
"
# disable old iptables modules
for m in $MODS; do echo blacklist $m; echo install $m /bin/false; done|sort >/etc/modprobe.d/local-blacklist.conf
compcp /etc/modprobe.d/local-blacklist.conf /etc/modprobe.d/local-blacklist.conf
# reboot compute hosts here

# restart calico-node in nftables mode
comp docker stop calico-node
comp docker rm calico-node
pdsh -w calico[1-3].local 'docker run --net=host --privileged --name=calico-node -d --restart=always -e ETCD_ENDPOINTS=http://172.31.0.48:2379 -e ETCD_DISCOVERY_SRV= -e NODENAME=%h -e FELIX_IPTABLESBACKEND=NFT -e IP_AUTODETECTION_METHOD="interface=eth.*" -v /var/log/calico:/var/log/calico -v /var/run/calico:/var/run/calico -v /var/lib/calico:/var/lib/calico -v /lib/modules:/lib/modules -v /run:/run quay.io/calico/node:latest'
sleep 3
ETCDCTL_API=3 etcdctl --endpoints http://$head_ip:2379 del /calico/resources/v3/projectcalico.org/felixconfigurations/default
