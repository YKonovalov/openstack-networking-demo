#!/bin/bash

TF_STATE="terraform/terraform.tfstate"
TF_DEMO_HOSTS_VARS="terraform/demo-hosts.auto.tfvars"

error() {
  echo "ERROR$1: $2" >&2
  exit $1
}

reqs() {
  for r in terraform jq ssh pdsh; do
    if ! which $r >/dev/null 2>&1; then
      error 2 "Please install $r"
    fi
  done
}

tf_hosts() {
  jq -r '.resources[]|select(.type=="vcd_vapp_vm")
  |[.instances[0].attributes.network[0].ip,
    .instances[0].attributes.guest_properties.hostname,
    (.instances[0].attributes.guest_properties.hostname|capture("^(?<shortname>[^.]+)").shortname)]
  |@tsv' $TF_STATE
}

tf_hosts_static() {
  tf_vars_read "$TF_DEMO_HOSTS_VARS" >/dev/null
  for host in control head compute1 compute2 compute3; do
    echo $(eval echo \$ip_${host}) $host
  done
}

tf_vars_read() {
  if ! [ -f "$1" ]; then
    error 2 "File not found: $1"
  fi
  while read key e value; do
    echo $key=$value
    eval "$key=$value"
  done << EOF
`cat "$1"`
EOF
}

gen_hosts() {
echo "127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
192.168.192.10	build"
tf_hosts_static
}

set_inventory() {
  all="$(echo $(tf_hosts_static|awk '{print $1}')|tr ' ' ',')"
  echo $all
  control="$(echo $(tf_hosts_static|grep control|awk '{print $1}')|tr ' ' ',')"
  echo $control
}

cp_some() {
  PDSH_SSH_ARGS_APPEND="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
    pdcp -l centos -w "$1" "$2" "$3"
}

on_some() {
  PDSH_SSH_ARGS_APPEND="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
    pdsh -l centos -w "$1" "$2"
}

cp_all() {
  cp_some $all "$1" "$2"
}

on_all() {
  on_some $all "$1"
}

cp_control() {
  cp_some $control "$1" "$2"
}

on_control() {
  on_some $control "$1"
}


copy_hosts_file() {
  gen_hosts | tee hosts
  cp_all hosts /tmp/hosts
  on_all 'cat /tmp/hosts|sudo tee /etc/hosts'
}

copy_scripts() {
  tar cvf - control-node-scripts|ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null centos@$control 'sudo tar xvf - -C /root --strip-components=1'
}

configure_ssh_equiv() {
on_control 'sudo bash -c \
"[ -f /root/.ssh/id_rsa ]||(
  ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa -N \"\" &&
   cat /home/centos/.ssh/authorized_keys /root/.ssh/id_rsa.pub|
     tee /root/.ssh/authorized_keys
)"'
#ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -A root@$control "PDSH_SSH_ARGS_APPEND='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null' pdcp -w head,compute[1-3] .ssh/* .ssh/"
}

tf_apply() {
  (
  cd terraform
  terraform apply
  )
}
echo
#tf_apply
set_inventory
copy_hosts_file
copy_scripts
configure_ssh_equiv

echo
echo "Please login to control node with enabled ssh-agent"
echo "  ssh -A root@$control"
echo "and run following commands:"
echo "  sh 00-host-centos8-prepare.sh"
echo
echo "Then connect without agent:"
echo "  ssh root@$control"
echo "and run:"
echo "  sh 02-os-setup-via-kayobe-plus-tf-dev.sh"
