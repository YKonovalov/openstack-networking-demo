#!/bin/sh
# must disable ssh-agent so that disconnected ssh sessions will not break playbooks
unset SSH_AUTH_SOCK

rm -f /tmp/tlog

tlog() {
  \time -f "%E %C (exit code: %X)" -a -o /tmp/tlog $@
}

time (
  echo "FIXME2: Change iface name to eth0, otherwise kolla-ansible will fail to find host ip"
  sed -i "s/common_interface: .*/common_interface: eth0/" /etc/kayobe/inventory/group_vars/compute/network-interfaces

  source ~/kayobe.rc
  tlog kayobe   control host bootstrap
  tlog kayobe overcloud host configure
  #pdsh -g compute ip r r default via 172.16.0.1 dev vhost0

  echo "FIXME3: should be installed by 'kayobe overcloud host configure'"
  pdsh -g head,compute '/opt/kayobe/venvs/kolla-ansible/bin/pip install docker-compose'
  pdsh -a 'timedatectl set-timezone Europe/Moscow'

)
