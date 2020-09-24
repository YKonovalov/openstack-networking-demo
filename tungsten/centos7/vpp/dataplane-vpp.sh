#!/bin/bash -e

DATAPLANE_NAME="vpp"
DATAPLANE_SUPPORTED_INGRESS_MPLS_IN_IP_ENCAPSULATIONS="gre"          # none,ip,gre,udp
DATAPLANE_SUPPORTED_EGRESS_MPLS_IN_IP_ENCAPSULATIONS="gre"           # none,ip,gre,udp
DATAPLANE_SUPPORTED_EGRESS_IP_TUNNELING_METHODS="device"             # device or route
DATAPLANE_SUPPORTED_EGRESS_IP_TUNNELING_DEVICE_CONTROL_TYPE="device" # device or route

API="
dataplaneCreate
dataplaneDelete
dataplaneStatus
dataplaneTundevStaticGreCreate
dataplaneTundevStaticGreDelete
dataplaneTundevStaticGreList
dataplaneTundevStaticUdpCreate
dataplaneTundevStaticUdpDelete
dataplaneTundevStaticUdpList
dataplaneTundevDynamicIngressGreCreate
dataplaneTundevDynamicIngressGreDelete
dataplaneTundevDynamicIngressGreList
dataplaneTundevDynamicIngressUdpCreate
dataplaneTundevDynamicIngressUdpDelete
dataplaneTundevDynamicIngressUdpList
dataplaneTundevDynamicEgressGreCreate
dataplaneTundevDynamicEgressGreDelete
dataplaneTundevDynamicEgressGreList
dataplaneTundevDynamicEgressUdpCreate
dataplaneTundevDynamicEgressUdpDelete
dataplaneTundevDynamicEgressUdpList
dataplaneRouteAddOrDelete
dataplaneRouteList
dataplaneIpRouteTableCreate
dataplaneIpRouteTableDelete
dataplaneIpRouteTableGet
dataplaneIpRouteTableList
dataplaneTundevCreate
dataplaneTundevDelete
dataplaneTundevList
dataplaneTunnelCreate
dataplaneTunnelDelete
dataplaneTunnelList
dataplaneVrfCreate
dataplaneVrfDelete
dataplaneVrfGet
dataplaneVrfList
"

vppInstall(){
  if [ -z "$(which vppctl 2>/dev/null)" ]; then
    curl -s https://packagecloud.io/install/repositories/fdio/master/script.rpm.sh | sudo bash
    yum -y install vpp
  fi
}

vppConfigure(){
  pkill vpp
  cat > /etc/vpp/startup.conf << \EOF
unix { cli-listen /run/vpp/cli.sock cli-prompt sgw }
plugins { plugin dpdk_plugin.so { disable } }
EOF
  vpp -c /etc/vpp/startup.conf
  sleep 1
}

vppInit(){
  vppctl mpls table add 0
  vppctl create host-interface name eth0
  vppctl set interface mac address host-eth0 $mac
  vppctl set int ip address host-eth0 $ipp
  vppctl set int state host-eth0 up
}

function dataplaneCreate() {
  vppInstall
  vppConfigure
  vppInit
}

function dataplaneDelete() {
  pkill vpp
  rm -f /etc/vpp/startup.conf
}

function dataplaneStatus() {
  vppctl show int addr
  vppctl show ip neighbors
  vppctl show ip fib 192.168.168.1/32
  vppctl ping 192.168.168.1 source loop0

  vppctl show ip neighbors

  vppctl ping 192.168.168.1 source loop0 &
  tcpdump -ev -c3 -ni eth0 proto gre
}

vrfCreateDataplane(){
  vppctl create loopback interface
  vppctl set interface ip address loop0 192.168.168.168/32
  vppctl set interface mpls loop0 enable
  vppctl set interface state loop0 up
  vppctl mpls local-label add 21 eos via ip4-lookup-in-table 0
}

tundevCreate()
  vppctl create gre tun src $ip dst $gre_ip
  vppctl set interface mpls $gre_name enable
  vppctl set int state $gre_name up
}

routeAddOrDelete(){
  vppctl ip route add 192.168.168.1/32 via $gre_name out-labels 19
}

hostip(){
  ip -o a s dev $1|awk '$3=="inet" {print $4}'
}

hostmac(){
  ip -o link show dev $1|sed "s;.*link/ether \([^[:blank:]]\+\).*;\1;"
}

ipp=$(hostip eth0)
ip=${ipp%%/*}
plen=${ipp##*/}
gre_ip="172.31.0.5"
gre_name="gre0"
mac=$(hostmac eth0)

dataplaneCreate
vrfCreateDataplane
tundevCreate
routeAddOrDelete
dataplaneStatus
