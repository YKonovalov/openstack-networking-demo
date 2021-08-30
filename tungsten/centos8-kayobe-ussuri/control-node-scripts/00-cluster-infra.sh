#!/bin/bash

export PDSH_SSH_ARGS_APPEND='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'

echo "Wait for cloud-init to finnish"
cloud-init status --wait

test -f /root/.ssh/id_rsa||ssh-keygen -t rsa -b 4096 -N "" -f /root/.ssh/id_rsa
ssh-copy-id -o StrictHostKeyChecking=no -i /root/.ssh/id_rsa root@localhost

echo "Sharing ssh cluster user identities and inventory"
pdcp -a -X control /root/.ssh/* /root/.ssh/
pdcp -a -X control /etc/hosts /etc/hosts
pdcp -a -X control /etc/genders /etc/genders
pdsh -a -X control 'hostname -f'

echo "Accepting all ssh hostkeys"
PDSH_SSH_ARGS_APPEND='-o StrictHostKeyChecking=no'
pdsh -a date

pdsh -a 'hostnamectl set-hostname %h'