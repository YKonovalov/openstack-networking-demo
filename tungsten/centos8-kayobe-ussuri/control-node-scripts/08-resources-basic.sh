#!/bin/sh

source ~/kayobe.env
source "$KOLLA_CONFIG_PATH/admin-openrc.sh"

dnf -y install centos-release-openstack-ussuri
dnf -y install python3-openstackclient python3-heatclient

fedora_url="https://mirror.yandex.ru/fedora/linux/releases/34/Cloud/x86_64/images/Fedora-Cloud-Base-34-1.2.x86_64.qcow2"
fedora_qcow="$(basename $fedora_url)"
cirros_url="http://download.cirros-cloud.net/0.5.2/cirros-0.5.2-x86_64-disk.img"
cirros_qcow="$(basename $cirros_url)"

[ -f "$fedora_qcow" ]|| curl -OL --progress "$fedora_url"
cat "$fedora_qcow"|openstack image create fedora --disk-format qcow2 --public --container-format bare

[ -f "$cirros_qcow" ]|| curl -OL --progress "$cirros_url"
cat "$cirros_qcow"|openstack image create cirros --disk-format qcow2 --public --container-format bare

openstack flavor create --public m1.tiny --id auto --ram 1024 --disk 10
openstack flavor create --public tempest1 --id 1 --ram 1024 --disk 1
openstack flavor create --public tempest2 --id 2 --ram 2048 --disk 1
