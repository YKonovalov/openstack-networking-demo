#!/bin/sh
. ./.config.sh
. ./common/functions.sh
OS=ussuri

# on the kayobe control host
yum install -y python3-devel libffi-devel gcc openssl-devel python3-libselinux time
#
# pdsh -w head,compute[1-3] 'cat /root/.ssh/authorized_keys >> /home/kolla/.ssh/authorized_keys'
#
cd
mkdir src

git clone https://github.com/openstack/kayobe.git -b stable/$OS src/kayobe

virtualenv-3 "venvs/kayobe"
source "venvs/kayobe/bin/activate"
 pip install -U pip
 pip install src/kayobe
deactivate

mkdir -p /etc/kayobe/inventory/group_vars/{controllers,compute,overcloud} /etc/kayobe/kolla/config

cat > /etc/kayobe/kolla/config/nova.conf << EOF
[libvirt]
virt_type=qemu
EOF

cat > /etc/kayobe/inventory/groups << EOF
[seed]
[controllers]
[compute]

[overcloud:children]
controllers
compute

[docker:children]
seed
controllers
compute

# we don't use network group yet, but playbooks fail unless we define it:
[network:children]
controllers
[storage]
[monitoring]
EOF

cat > /etc/kayobe/inventory/hosts << EOF
localhost ansible_connection=local config_file=../tf.yml
[controllers]
head ansible_host=head
[compute]
compute1 ansible_host=compute1
compute2 ansible_host=compute2
compute3 ansible_host=compute3
EOF

cat > /etc/kayobe/inventory/group_vars/controllers/network-interfaces << EOF
common_interface: eth0
common_bootproto: none
EOF

cat > /etc/kayobe/inventory/group_vars/compute/network-interfaces << EOF
common_interface: vhost0
common_bootproto: none
EOF

cat > /etc/kayobe/inventory/group_vars/overcloud/ansible_python_interpreter << EOF
ansible_python_interpreter: "{{ virtualenv_path }}/kayobe/bin/python"
EOF

cat >  /etc/kayobe/networks.yml << EOF
admin_oc_net_name: common
oob_oc_net_name: common
provision_oc_net: common
oob_wl_net_name: common
provision_wl_net_name: common
cleaning_net_name: common
internal_net_name: common
public_net_name: common
tunnel_net_name: common
external_net_name: common
storage_net_name: common
storage_mgmt_net_name: common
inspection_net_name: common
EOF

cat >  /etc/kayobe/networks-vars.yml << EOF
common_ips:
 head: 192.168.192.3
 compute1: 192.168.192.4
 compute2: 192.168.192.5
 compute3: 192.168.192.6
common_fqdn: head.
common_vip_address: 192.168.192.3
EOF

cat > /etc/kayobe/hosts-vars.yml << EOF
disable-glean: true
docker_storage_driver: overlay
seed_lvm_groups: []
controller_lvm_groups: []
compute_lvm_groups: []
EOF

cat > /etc/kayobe/kolla.yml << EOF
openstack_release: $OS
openstack_branch: stable/$OS
kolla_ansible_custom_passwords:
 keystone_admin_password: admin
 kolla_ssh_key:
  private_key: "{{ lookup('file', ssh_private_key_path) }}"
  public_key: "{{ lookup('file', ssh_public_key_path) }}"
kolla_enable_neutron_provider_networks: False
kolla_neutron_ml2_mechanism_drivers: [ovn]
kolla_neutron_ml2_type_drivers: [geneve]
kolla_neutron_ml2_tenant_network_types: [geneve]
kolla_neutron_ml2_extension_drivers: [port_security]
EOF

cat > /etc/kayobe/kolla/globals.yml << EOF
customize_etc_hosts: False
neutron_plugin_agent: "ovn"
computes_need_external_bridge: False
EOF

cat > /etc/kayobe/dns.yml << EOF
resolv_is_managed: false
EOF

cat > /etc/kayobe/ssh.yml << EOF
ssh_key_name: id_ed25519
EOF

cat > /etc/kayobe/kolla-disabled.yml << EOF
kolla_enable_aodh: false
kolla_enable_barbican: false
kolla_enable_blazar: false
kolla_enable_cadf_notifications: false
kolla_enable_ceilometer: false
kolla_enable_central_logging: false
kolla_enable_ceph: false
kolla_enable_ceph_mds: false
kolla_enable_ceph_nfs: false
kolla_enable_ceph_rgw: false
kolla_enable_chrony: false
kolla_enable_cinder: false
kolla_enable_cinder_backend_hnas_iscsi: false
kolla_enable_cinder_backend_hnas_nfs: false
kolla_enable_cinder_backend_iscsi: false
kolla_enable_cinder_backend_lvm: false
kolla_enable_cinder_backend_nfs: false
kolla_enable_cinder_backend_zfssa_iscsi: false
kolla_enable_cloudkitty: false
kolla_enable_congress: false
kolla_enable_designate: false
kolla_enable_etcd: false
kolla_enable_fluentd: false
kolla_enable_freezer: false
kolla_enable_gnocchi: false
kolla_enable_grafana: false
kolla_enable_haproxy: false
kolla_enable_heat: false
kolla_enable_influxdb: false
kolla_enable_ironic: false
kolla_enable_ironic_ipxe: false
kolla_enable_ironic_pxe_uefi: false
kolla_enable_iscsid: false
kolla_enable_karbor: false
kolla_enable_kuryr: false
kolla_enable_magnum: false
kolla_enable_manila: false
kolla_enable_manila_backend_generic: false
kolla_enable_manila_backend_hnas: false
kolla_enable_manila_backend_cephfs_native: false
kolla_enable_manila_backend_cephfs_nfs: false
kolla_enable_mariabackup: false
kolla_enable_mistral: false
kolla_enable_monasca: false
kolla_enable_mongodb: false
kolla_enable_multipathd: false
kolla_enable_murano: false
kolla_enable_octavia: false
kolla_enable_osprofiler: false
kolla_enable_panko: false
kolla_enable_prometheus: false
kolla_enable_qdrouterd: false
kolla_enable_rally: false
kolla_enable_sahara: false
kolla_enable_searchlight: false
kolla_enable_senlin: false
kolla_enable_skydive: false
kolla_enable_solum: false
kolla_enable_storm: false
kolla_enable_swift: false
kolla_enable_tacker: false
kolla_enable_telegraf: false
kolla_enable_tempest: false
kolla_enable_trove: false
kolla_enable_vitrage: false
kolla_enable_vmtp: false
kolla_enable_watcher: false
kolla_enable_zun: false
EOF

cat > ~/kayobe.rc << EOF
export KAYOBE_CONFIG_PATH="/etc/kayobe"
export KOLLA_CONFIG_PATH="/etc/kolla"

export KAYOBE_DATA_FILES_PATH="$(realpath src/kayobe          )"
export KOLLA_SOURCE_PATH="$(realpath      src/kolla-ansible   )"

export KAYOBE_VENV_PATH="$(realpath      "venvs/kayobe"       )"
export KOLLA_VENV_PATH=$(realpath        "venvs/kolla-ansible")

source "\$KAYOBE_VENV_PATH/bin/activate"
#cd "\$KAYOBE_DATA_FILES_PATH"
EOF

ktbox_in(){
  ssh head 'docker exec -i -u root -w /var/lib/kolla/config_files kolla_toolbox bash -c "source admin-openrc.sh; '"$@"'"'
}
alias openstack="ktbox openstack"

ktbox(){
  ssh -n head 'docker exec -i -u root -w /var/lib/kolla/config_files kolla_toolbox bash -c "source admin-openrc.sh; '"$@"'"'
}
alias openstack_stdin="ktbox_in openstack"

openstackResourcesAdd(){
  openstack service list
  curl -OL --progress http://download.cirros-cloud.net/0.5.1/cirros-0.5.1-x86_64-disk.img
  cat cirros-0.5.1-x86_64-disk.img|openstack_stdin image create cirros2 --disk-format qcow2 --public --container-format bare
  openstack flavor create --public m1.tiny --id auto --ram 1024 --disk 10
  while read net cidr; do
    netid="$(openstack network create --share $net -c id -f value < /dev/null)"; [ -n "$netid" ]
    openstack subnet create --network $net --ip-version 4 --subnet-range $cidr $net-v4
    for name in a b c; do
      openstack server create --flavor m1.tiny --image cirros2 --network=$netid $net-$name
    done
  done << EOF
pub-a 192.168.168.0/24
pub-b 192.168.169.0/24
EOF
}


networkSetConf() {
cat > /tmp/ifcfg-eth0 << EOF
DEVICE=eth0
BOOTPROTO=none
ONBOOT=yes
NM_CONTROLLED=no
EOF
cat > /tmp/ifcfg-vhost0 << EOF
DEVICE=vhost0
BOOTPROTO=none
ONBOOT=yes
TYPE=kernel
NM_CONTROLLED=NO
BIND_INT=eth0
EOF
cat > /tmp/80-vhost.network << EOF
[Match]
Name=vhost*
[Network]
DHCP=yes
LLMNR=no
MulticastDNS=no
EOF
  cp-compute /tmp/ifcfg-eth0 /etc/sysconfig/network-scripts/ifcfg-eth0
  cp-compute /tmp/ifcfg-vhost0 /etc/sysconfig/network-scripts/ifcfg-vhost0
  on-compute rm -f /etc/systemd/network/*
  cp-compute /tmp/80-vhost.network /etc/systemd/network/80-vhost-dhcp.network
  on-all 'ln -fs /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf'
  on-compute 'rm -f /etc/sysconfig/network-scripts/ifcfg-p-*'
  on-compute 'systemctl restart network; systemctl restart systemd-networkd'
}

rm -f /tmp/tlog
alias tlog='\time -f "%E %C (exit code: %X)" -a -o /tmp/tlog'
time (
  source ~/kayobe.rc
  tlog kayobe   control host bootstrap
  tlog kayobe overcloud host configure
  tlog kayobe overcloud service deploy

  networkSetConf

  # resources
  cp-head /etc/kolla/*-openrc.sh /etc/kolla/kolla-toolbox/
  time openstackResourcesAdd

  cat /tmp/tlog
)
