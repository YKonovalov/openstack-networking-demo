#!/bin/sh
alias all='pdsh -w chead,calico[1-3]'
alias head='pdsh -w chead'
alias comp='pdsh -w calico[1-3]'
alias allcp='pdcp -w chead,calico[1-3]'

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
sed -i 's/^\(CONFIG_COMPUTE_HOSTS\)=.*/\1=172.31.0.31,172.31.0.30,172.31.0.11/' /root/openstack.txt
packstack --answer-file=/root/openstack.txt
