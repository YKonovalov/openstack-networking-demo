#!/bin/bash

TF_VARS="terraform/terraform.tfvars"
TF_DEMO_STATIC_VARS="terraform/demo-constants.auto.tfvars"
TF_DEMO_NETWORK_VARS="terraform/demo-network.auto.tfvars"
TF_DEMO_VARS="terraform/demo.auto.tfvars"
TF_DEMO_USERDATA="terraform/templates/userdata.yaml"
TF_DEMO_HOSTS_VARS="terraform/demo-hosts.auto.tfvars"
reqs() {
  for r in terraform base64; do
    if ! which $r >/dev/null 2>&1; then
      error 2 "Please install $r"
    fi
  done
}

error() {
  echo "ERROR$1: $2" >&2
  exit $1
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

userdata(){
sed \
  -e "s:==IP==:$1:" \
  -e "s:==GATEWAY==:$2:" \
  -e "s:==DOMAIN==:$3:" \
  "$TF_DEMO_USERDATA"
}

tf_write_demo_vars() {
tee "$TF_DEMO_VARS" << EOF
demo = "${vcd_user:0:2}-ussuri-tf-centos8"
EOF
}

tf_write_hosts_vars() {
  n=${static_ip_pool_start_address%.*}
  h=${static_ip_pool_start_address##*.}
  cat /dev/null > "$TF_DEMO_HOSTS_VARS"
  for host in control head compute1 compute2 compute3; do
    ip="$n.$h"
    ((h++))
    echo ip_${host} = \"$ip\"
    echo user_data_${host} = \"$(userdata $ip/24 $gateway $demo|base64 -w0)\"
  done |sort > "$TF_DEMO_HOSTS_VARS"
}

tf_apply() {
  (
  cd terraform
  terraform apply
  )
}

reqs

eval `tf_vars_read "$TF_VARS"`
if [ -z "$vcd_user" ]; then
  error 1 "Please setup vars in $TF_VARS ."
fi

tf_write_demo_vars
tf_vars_read "$TF_DEMO_VARS"
tf_vars_read "$TF_DEMO_STATIC_VARS"
tf_vars_read "$TF_DEMO_NETWORK_VARS"
tf_write_hosts_vars

tf_apply

echo
echo "Please wait for all hosts to upgrade and reboot with new kernel and run:"
echo "  sh 02-set-control.sh"
