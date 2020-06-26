#!/bin/bash
# on the kayobe control host

OS=train

yum install -y python3-devel libffi-devel gcc openssl-devel python3-libselinux

cd
mkdir -p src $virtualenv_path

git clone https://github.com/openstack/kayobe.git -b stable/$OS src/kayobe
empty_match="\(^#\|---\|^$\|workaround_ansible_issue_8743: yes\)"
sed -i "/$empty_match/ d" src/kayobe/ansible/roles/kolla-ansible/templates/globals.yml.j2
sed -i "/neutron_plugin_agent/ d" src/kayobe/ansible/roles/kolla-ansible/templates/globals.yml.j2

virtualenv-3 "venvs/kayobe"
source "venvs/kayobe/bin/activate"
 pip install -U pip
 pip install src/kayobe
deactivate

pre_configure(){
  git clone https://github.com/openstack/kayobe-config.git -b stable/$OS src/kayobe-config
  grep -rv "$empty_match" src/kayobe-config/etc/kayobe/|
    while IFS=: read file line; do
      target="/${file#*/*/}"
      mkdir -p "$(dirname $target)"
      echo "$line" >> "$target";
    done
}

mkdir -p /etc/kayobe/inventory/group_vars/{seed,overcloud} /etc/kayobe/kolla

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
localhost ansible_connection=local
[seed]
build ansible_host=build
[controllers]
kolla ansible_host=kolla
[compute]
kolla1 ansible_host=kolla1
kolla2 ansible_host=kolla2
kolla3 ansible_host=kolla3
EOF

cat > /etc/kayobe/inventory/group_vars/seed/network-interfaces << EOF
common_interface: eth0
common_bootproto: dhcp
EOF

cat > /etc/kayobe/inventory/group_vars/overcloud/network-interfaces << EOF
common_interface: eth0
common_bootproto: dhcp
EOF

cat > /etc/kayobe/inventory/group_vars/seed/ansible_python_interpreter << EOF
ansible_python_interpreter: "{{ virtualenv_path }}/kayobe/bin/python"
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
 kolla: 172.31.0.42
 kolla1: 172.31.0.40
 kolla2: 172.31.0.28
 kolla3: 172.31.0.6
 build: 172.31.0.25
common_fqdn: kolla.local
common_vip_address: 172.31.0.42
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
kolla_ansible_source_url: https://github.com/tungstenfabric/tf-kolla-ansible
kolla_ansible_source_version: contrail/$OS
kolla_ansible_custom_passwords:
 keystone_admin_password: admin
EOF

cat > /etc/kayobe/kolla/globals.yml << EOF
ironic_notification_manager_image_full:    opencontrailnightly/contrail-openstack-ironic-notification-manager:latest
nova_compute_opencontrail_init_image_full: opencontrailnightly/contrail-openstack-compute-init:latest
neutron_opencontrail_init_image_full:      opencontrailnightly/contrail-openstack-neutron-init:latest
heat_opencontrail_init_image_full:         opencontrailnightly/contrail-openstack-heat-init:latest

opencontrail_collector_ip:  172.31.0.42
opencontrail_webui_ip:      172.31.0.42
opencontrail_api_server_ip: 172.31.0.42

enable_opencontrail_trunk: True
enable_opencontrail_rbac: no
contrail_ca_file: /etc/contrail/ssl/certs/ca-cert.pem

neutron_plugin_agent: opencontrail
neutron_fwaas_version: v2
metadata_secret: contrail
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

time (. ~/kayobe.rc
    time kayobe control host bootstrap
    time kayobe overcloud host configure
    time kayobe overcloud service deploy
deactivate)

add_contrail() {
  cd kolla/tf-ansible-deployer/
  . venv/bin/activate
    ansible-playbook -i inventory/ playbooks/install_contrail.yml
  deactivate
}
