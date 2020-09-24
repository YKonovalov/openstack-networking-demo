#!/bin/bash -e
. dataplane-vpp.sh

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
