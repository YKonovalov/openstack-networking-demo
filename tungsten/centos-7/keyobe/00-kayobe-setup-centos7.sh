#!/bin/bash
# on the kayobe control host

OS=train

yum install -y python3-devel libffi-devel gcc openssl-devel python3-libselinux time

cd
mkdir src

git clone https://github.com/openstack/kayobe.git -b stable/$OS src/kayobe
git clone https://github.com/tungstenfabric/tf-ansible-deployer.git -b master src/tf-ansible-deployer

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

mkdir -p /etc/kayobe/inventory/group_vars/{seed,overcloud} /etc/kayobe/kolla/config

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
kolla_ansible_source_url: https://github.com/tungstenfabric/tf-kolla-ansible.git
kolla_ansible_source_version: contrail/$OS
kolla_ansible_custom_passwords:
 keystone_admin_password: admin
EOF

cat > /etc/kayobe/kolla/globals.yml << EOF
heat_opencontrail_init_image_full:               tungstenfabric/contrail-openstack-heat-init:latest
ironic_notification_manager_image_full:          tungstenfabric/contrail-openstack-ironic-notification-manager:latest
neutron_opencontrail_init_image_full:            tungstenfabric/contrail-openstack-neutron-init:latest
neutron_opencontrail_ml2_init_image_full:        tungstenfabric/contrail-openstack-neutron-ml2-init:latest
nova_compute_opencontrail_init_image_full:       tungstenfabric/contrail-openstack-compute-init:latest

contrail_ca_file: /etc/contrail/ssl/certs/ca-cert.pem
contrail_dm_integration: True
enable_opencontrail_rbac: False
enable_opencontrail_trunk: True

metadata_secret: contrail
neutron_plugin_agent: opencontrail
#neutron_plugin_agent: opencontrail-ml2
neutron_fwaas_version: v2

opencontrail_api_server_ip: 172.31.0.42
opencontrail_collector_ip:  172.31.0.42
opencontrail_webui_ip:      172.31.0.42
EOF

cat > /etc/kayobe/tf.yml << EOF
provider_config:
  bms:
    domainsuffix: local
instances:
  kolla:
    provider: bms
    ip: 172.31.0.42
    roles:
      config_database:
      config:
      control:
      analytics_database:
      analytics:
      webui:
      openstack:
  kolla1:
    provider: bms
    ip: 172.31.0.40
    roles:
      vrouter:
      openstack_compute:
  kolla2:
    provider: bms
    ip: 172.31.0.28
    roles:
      vrouter:
      openstack_compute:
  kolla3:
    provider: bms
    ip: 172.31.0.6
    roles:
      vrouter:
      openstack_compute:
global_configuration:
  CONTAINER_REGISTRY: tungstenfabric
contrail_configuration:
  CLOUD_ORCHESTRATOR: openstack
  OPENSTACK_VERSION: train
  CONTRAIL_VERSION: latest
  AUTH_MODE: keystone
  KEYSTONE_AUTH_URL_VERSION: /v3
kolla_config:
  kolla_passwords:
    keystone_admin_password: admin
    metadata_secret: contrail
  customize:
    nova.conf: |
      [libvirt]
      virt_type=qemu
      cpu_mode=none
  kolla_globals:
    neutron_plugin_agent: opencontrail-ml2
    enable_opencontrail_rbac: no
    contrail_dm_integration: True
    neutron_type_drivers: "local,vlan,gre,vxlan"
    neutron_tenant_network_types: "local,vlan"
    enable_aodh: no
    enable_barbican: no
    enable_blazar: no
    enable_cadf_notifications: no
    enable_ceilometer: no
    enable_central_logging: no
    enable_ceph_mds: no
    enable_ceph_nfs: no
    enable_ceph: no
    enable_ceph_rgw: no
    enable_chrony: no
    enable_cinder_backend_hnas_iscsi: no
    enable_cinder_backend_hnas_nfs: no
    enable_cinder_backend_iscsi: no
    enable_cinder_backend_lvm: no
    enable_cinder_backend_nfs: no
    enable_cinder_backend_zfssa_iscsi: no
    enable_cinder: no
    enable_cloudkitty: no
    enable_congress: no
    enable_designate: no
    enable_etcd: no
    enable_fluentd: no
    enable_freezer: no
    enable_gnocchi: no
    enable_grafana: no
    enable_haproxy: no
    enable_heat: no
    enable_influxdb: no
    enable_ironic_ipxe: no
    enable_ironic: no
    enable_ironic_pxe_uefi: no
    enable_iscsid: no
    enable_karbor: no
    enable_kuryr: no
    enable_magnum: no
    enable_manila_backend_cephfs_native: no
    enable_manila_backend_cephfs_nfs: no
    enable_manila_backend_generic: no
    enable_manila_backend_hnas: no
    enable_manila: no
    enable_mariabackup: no
    enable_mistral: no
    enable_monasca: no
    enable_mongodb: no
    enable_multipathd: no
    enable_murano: no
    enable_octavia: no
    enable_osprofiler: no
    enable_panko: no
    enable_prometheus: no
    enable_qdrouterd: no
    enable_rally: no
    enable_sahara: no
    enable_searchlight: no
    enable_senlin: no
    enable_skydive: no
    enable_solum: no
    enable_storm: no
    enable_swift: no
    enable_tacker: no
    enable_telegraf: no
    enable_tempest: no
    enable_trove: no
    enable_vitrage: no
    enable_vmtp: no
    enable_watcher: no
    enable_zun: no
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
  ssh kolla 'docker exec -i -u root -w /var/lib/kolla/config_files kolla_toolbox bash -c "source admin-openrc.sh; '"$@"'"'
}

ktbox(){
  ssh -n kolla 'docker exec -i -u root -w /var/lib/kolla/config_files kolla_toolbox bash -c "source admin-openrc.sh; '"$@"'"'
}

openstackResourcesAdd(){
  alias openstack="ktbox openstack"
  alias openstack_stdin="ktbox_in openstack"
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

rm -f /tmp/tlog
alias tlog='\time -f "%E %C (exit code: %X)" -a -o /tmp/tlog'
time (
  source ~/kayobe.rc
  tlog kayobe control host bootstrap
  tlog kayobe overcloud host configure
  tlog kayobe overcloud service deploy
  source venvs/kolla-ansible/bin/activate
    tlog ansible-playbook -i /etc/kayobe/inventory -e config_file=/etc/kayobe/tf.yml src/tf-ansible-deployer/playbooks/install_contrail.yml
  deactivate
  tlog openstackResourcesAdd
  cat /tmp/tlog
)
