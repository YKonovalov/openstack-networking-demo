#!/bin/sh

alias all='pdsh -w ovn,ovn[1-3]'
alias head='pdsh -w ovnc'
alias comp='pdsh -w ovnc[1-3]'
alias allcp='pdcp -w ovn,ovnc[1-3]'
comp_ip_list="$(echo $(grep ovnc /etc/hosts |grep -v `hostname`|awk "{print \$1}")|tr ' ' ',')"

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
