#!/bin/sh -e
if [ -z "$(which vppctl 2>/dev/null)" ]; then
  curl -s https://packagecloud.io/install/repositories/fdio/master/script.rpm.sh | sudo bash
  yum -y install vpp
fi

pkill vpp

cat > /etc/vpp/startup-a.conf << \EOF
unix { cli-listen /run/vpp/cli-a.sock cli-prompt a log /var/log/vpp/a.log }
api-segment { prefix a }
plugins { plugin dpdk_plugin.so { disable } }
EOF
cat > /etc/vpp/startup-b.conf << \EOF
unix { cli-listen /run/vpp/cli-b.sock cli-prompt b log /var/log/vpp/b.log }
api-segment { prefix b }
plugins { plugin dpdk_plugin.so { disable } }
EOF

vpp -c /etc/vpp/startup-a.conf
vpp -c /etc/vpp/startup-b.conf

alias vppctla='vppctl -s /run/vpp/cli-a.sock'
alias vppctlb='vppctl -s /run/vpp/cli-b.sock'

ip link add name a type veth peer name b
ip link set dev a up
ip link set dev b up
sleep 3

vppctla mpls table add 0
vppctla create host-interface name a
vppctla set int ip address host-a 10.10.1.1/24
vppctla set int state host-a up

vppctla create loopback interface
vppctla set interface ip address loop0 1.1.1.1/32
vppctla set interface mpls loop0 enable
vppctla set interface state loop0 up

vppctla create gre tun src 10.10.1.1 dst 10.10.1.2
vppctla set interface mpls gre0 enable
vppctla set int state gre0 up

#vppctla mpls local-label 21 1.1.1.1/32
vppctla mpls local-label add 21 eos via ip4-lookup-in-table 0
vppctla ip route add 2.2.2.2/32 via gre0 out-labels 22


vppctlb mpls table add 0
vppctlb create host-interface name b
vppctlb set int ip address host-b 10.10.1.2/24
vppctlb set int state host-b up

vppctlb create gre tun src 10.10.1.2 dst 10.10.1.1
vppctlb set interface mpls gre0 enable
vppctlb set int state gre0 up

vppctlb create loopback interface
vppctlb set interface ip address loop0 2.2.2.2/32
vppctlb set interface mpls loop0 enable
vppctlb set interface state loop0 up

#vppctlb mpls local-label 22 2.2.2.2/32
vppctlb mpls local-label add 22 eos via ip4-lookup-in-table 0
vppctlb ip route add 1.1.1.1/32 via gre0 out-labels 21

vppctla show int addr
vppctlb show int addr
