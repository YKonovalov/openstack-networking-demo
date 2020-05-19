#!/bin/sh
cluster=ovn
alias all='pdsh -w ovn,ovn[1-3]'
alias head='pdsh -w ovn'
alias comp='pdsh -w ovn[1-3]'
alias allcp='pdcp -w ovn,ovn[1-3]'
comp_ip_list="$(echo $(awk -v m="$cluster.$" "\$3~m {print \$1}" /etc/hosts)|tr ' ' ',')"

all dnf -y update
all dnf -y install centos-release-openstack-train
all dnf -y update

all dnf -y install openstack-packstack

cat > /etc/hiera.yaml << \EOF
---
:backends:
  - yaml
:hierarchy:
  - defaults
  - "%{clientcert}"
  - "%{environment}"
  - global

:yaml:
# datadir is empty here, so hiera uses its defaults:
# - /var/lib/hiera on *nix
# - %CommonAppData%\PuppetLabs\hiera\var on Windows
# When specifying a datadir, make sure the directory exists.
  :datadir:
EOF
allcp /etc/hiera.yaml /etc/hiera.yaml

packstack --allinone --gen-answer-file=/root/openstack.txt
sed -i "s/^\(CONFIG_COMPUTE_HOSTS\)=.*/\1=$comp_ip_list/" /root/openstack.txt
packstack --answer-file=/root/openstack.txt
