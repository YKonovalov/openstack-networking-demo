#!/bin/bash

N=sgw1,sgw2,sgw3

alias all="pdsh -w $N"
alias allcp="pdcp -w $N"

function init_ssh(){
for h in ${N//,/ }; do
  ssh fedora@$h date
  ssh fedora@$h 'sudo sed -i "s/disable_root: true/disable_root: false/" /etc/cloud/cloud.cfg'
  cat /root/.ssh/authorized_keys|ssh fedora@$h 'sudo tee /root/.ssh/authorized_keys'
  ssh $h date
done
}

function init_pkgs(){
pdsh -w "$1" 'dnf -y update'
pdsh -w "$1" 'dnf -y install pdsh pdsh-rcmd-ssh'
pdsh -w "$1" 'hostnamectl set-hostname %h'
pdcp -w "$1" /root/.ssh/* /root/.ssh/
pdcp -w "$1" /etc/hosts /etc/hosts
}

function init_pkgs(){
all 'dnf -y update'
all 'dnf -y install pdsh pdsh-rcmd-ssh'
all 'hostnamectl set-hostname %h'
allcp /root/.ssh/* /root/.ssh/
allcp /etc/hosts /etc/hosts
}

function init_net(){
all 'dnf -y install strace tcpdump bind-utils'
all systemctl disable NetworkManager
all systemctl stop NetworkManager
all systemctl enable systemd-networkd
all 'echo -e "[Match]\nName=eth*\n[Network]\nDHCP=yes\n" > /etc/systemd/network/80-dhcp.network'
all systemctl start systemd-networkd
all 'ln -fs /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf'
all systemctl enable systemd-resolved
all systemctl start systemd-resolved
}

init_ssh
init_pkgs
init_net
