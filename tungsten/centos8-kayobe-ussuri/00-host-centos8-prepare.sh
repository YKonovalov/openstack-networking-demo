#!/bin/bash

N=head,compute1,compute2,compute3

alias all="pdsh -w $N"
alias allcp="pdcp -w $N"

function init_ssh(){
for h in ${N//,/ }; do
  ssh centos@$h date
  ssh centos@$h 'sudo sed -i "s/disable_root: 1/disable_root: 0/" /etc/cloud/cloud.cfg'
  cat /root/.ssh/authorized_keys|ssh centos@$h 'sudo tee /root/.ssh/authorized_keys'
  ssh $h date
done
}

function init_pkgs(){
all 'dnf -y remove cockpit-ws'
all 'dnf -y update'
all 'dnf config-manager --set-enabled PowerTools'
all 'dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm'

all 'dnf -y install https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/29/Everything/x86_64/os/Packages/p/pdsh-2.31-12.fc29.x86_64.rpm https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/29/Everything/x86_64/os/Packages/p/pdsh-rcmd-ssh-2.31-12.fc29.x86_64.rpm'

all 'hostnamectl set-hostname %h'
allcp /root/.ssh/* /root/.ssh/
allcp /etc/hosts /etc/hosts
}

function init_net(){
all 'dnf -y install strace tcpdump bind-utils'
all 'dnf -y install systemd-networkd'
all systemctl disable NetworkManager
all systemctl stop NetworkManager
all systemctl enable systemd-networkd
all 'echo -e "[Match]\nName=eth0\n[Network]\nDHCP=yes\n" > /etc/systemd/network/80-eth0.network'
all systemctl start systemd-networkd
all 'ln -fs /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf'
all 'sed -i "0,/^hosts:/s/^\(hosts:.*\)/#&\nhosts:      resolve/" /etc/nsswitch.conf'
all 'sed -i -e "s/^#\(LLMNR\)=yes/\1=no/" -e "s/^#\(MulticastDNS\)=yes/\1=no/" /etc/systemd/resolved.conf'
all systemctl enable systemd-resolved
all systemctl start systemd-resolved
}

function init_tools_on_vmware(){
all '[ `systemd-detect-virt` == "vmware" ] && dnf -y install open-vm-tools && systemctl enable --now vgauthd.service vmtoolsd.service'
}

init_ssh
init_pkgs
init_net
init_tools_on_vmware
