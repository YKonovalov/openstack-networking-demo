#!/bin/sh
name=`hostname`
local="$(ip -o r g 1|sed "s/.* src \([^[:blank:]]\+\).*/\1/")" #"
peers="$(grep calico /etc/hosts |grep -v `hostname`|awk "{print \$1, \$NF}")"

(
cat << EOF
router id $local;
filter export_bgp {
  if ( (ifname ~ "tap*") || (ifname ~ "cali*") || (ifname ~ "dummy1") ) then {
    if  net != 0.0.0.0/0 then accept;
  }
  reject;
}
protocol kernel {
  learn;
  persist;
  scan time 2;
  graceful restart;
  ipv4 {
    import all;
    export all;
  };
}
protocol device {
  scan time 2;
}
protocol direct {
   debug all;
   ipv4;
   interface "-dummy0", "dummy1", "eth*", "em*", "en*", "br-mgmt";
}
template bgp calico {
  local $local as 65001;
  multihop;
  graceful restart;
  ipv4 {
    import all;
    export filter export_bgp;
    next hop self;
  };
}
EOF

echo "$peers"|while read peer name; do
cat << EOF
protocol bgp $name from calico {
  neighbor $peer as 65001;
}
EOF
done
) >/etc/bird.conf
systemctl restart bird

