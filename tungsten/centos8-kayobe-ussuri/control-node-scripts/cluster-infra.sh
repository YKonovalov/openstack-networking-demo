#!/bin/bash

export PDSH_SSH_ARGS_APPEND='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'

echo "Wait for cloud-init to finnish"
cloud-init status --wait

test -f /root/.ssh/id_rsa||ssh-keygen -t rsa -b 4096 -N "" -f /root/.ssh/id_rsa
ssh-copy-id -o StrictHostKeyChecking=no -i /root/.ssh/id_rsa root@localhost

echo "Waiting for all nodes to become up"
systemctl restart whatsup-pingd
time (while ! whatsup -t --up >/dev/null; do sleep 1; echo -n .; done)
whatsup

echo "Wait for cloud-init to finnish on all nodes"
while true; do
  A="$(nodeattr -n "~(control||pdsh_all_skip)"|sort)"
  B="$(pdsh -a -X control 'cloud-init status --wait'|awk -F: '/status: done/{print $1}'|sort)"
  C=`comm -23 <(echo "$A") <(echo "$B")`
  if [ "$A" == "$B" ]; then
    break
  fi
  echo "Waiting for: "$A
  echo " already ready: "$B
  echo " still waiting: "$C
  sleep 6
done

echo "Sharing ssh cluster user identities and inventory"
pdcp -a -X control /root/.ssh/* /root/.ssh/
pdcp -a -X control /etc/hosts /etc/hosts
pdcp -a -X control /etc/genders /etc/genders
pdsh -a -X control 'hostname -f'

echo "Accepting all ssh hostkeys"
#PDSH_SSH_ARGS_APPEND='-o StrictHostKeyChecking=no'
echo -e "host *\n  StrictHostKeyChecking no\n" >> ~/.ssh/config
pdsh -a date
echo "Setting hostnames"
pdsh -a 'hostnamectl set-hostname %h'
