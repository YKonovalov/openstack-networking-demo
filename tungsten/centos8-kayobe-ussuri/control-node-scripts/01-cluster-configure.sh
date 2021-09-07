#!/bin/sh

resolve_host() {
  getent hosts $1|head -1|cut -d ' ' -f1
}

rhost="$(nodeattr -n build|head -1)"
rport="$(nodeattr -v $rhost docker_registry_listen_port)"

chost="$(nodeattr -n control|head -1)"
os="$(nodeattr -v $chost os)"
tf="$(nodeattr -v $chost tf)"
virt="$(nodeattr -v $chost virt)"

os="${os:-ussuri}"
tf="${tf:-dev}"
virt="${virt:-kvm}"

hhost="$(nodeattr -n head|head -1)"
head_ip=$(resolve_host $hhost)

mkdir -p /etc/kayobe/inventory/group_vars/{controllers,compute,overcloud} /etc/kayobe/kolla

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
`nodeattr -n head   |awk '{print $0, "ansible_host="$0}'`
[compute]
`nodeattr -n compute|awk '{print $0, "ansible_host="$0}'`
EOF

cat > /etc/kayobe/inventory/group_vars/controllers/network-interfaces << EOF
common_interface: eth0
common_bootproto: static
EOF
cat > /etc/kayobe/inventory/group_vars/compute/network-interfaces << EOF
common_interface: vhost0
common_bootproto: static
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
common_cidr: $(ip -j r s dev eth0 scope link|jq -r '.[0]|.dst')
common_gateway: $(ip -j r s dev eth0 default|jq -r '.[0]|.gateway')
common_ips:
`nodeattr -n "head||compute"|while read name; do echo " $name: $(resolve_host $name)"; done`
common_fqdn: head0.
common_vip_address: $head_ip
EOF

cat > /etc/kayobe/dns.yml << EOF
resolv_is_managed: False
EOF

cat > /etc/kayobe/hosts-vars.yml << EOF
disable-glean: true
docker_storage_driver: overlay
seed_lvm_groups: []
controller_lvm_groups: []
compute_lvm_groups: []
EOF

cat > /etc/kayobe/kolla.yml << EOF
openstack_release: $os
openstack_branch: stable/$os
#kolla_ansible_source_url: https://github.com/tungstenfabric/tf-kolla-ansible.git
kolla_ansible_source_url: https://github.com/YKonovalov/tf-kolla-ansible
kolla_ansible_source_version: contrail/$os
#kolla_ansible_user: root
kolla_ansible_custom_passwords:
 keystone_admin_password: admin
 metadata_secret: contrail
 kolla_ssh_key:
  private_key: "{{ lookup('file', ssh_private_key_path) }}"
  public_key: "{{ lookup('file', ssh_public_key_path) }}"
kolla_enable_neutron_provider_networks: False
kolla_enable_heat: true
EOF

cat > /etc/kayobe/kolla/globals.yml << EOF
tf_tag: "$tf"
tf_namespace: ""
tf_docker_registry: "$rhost:$rport"

contrail_ca_file: /etc/contrail/ssl/certs/ca-cert.pem
contrail_dm_integration: False
enable_opencontrail_rbac: False
enable_opencontrail_trunk: True

#metadata_secret: contrail
neutron_plugin_agent: opencontrail
neutron_fwaas_version: v2

opencontrail_api_server_ip: $head_ip
opencontrail_collector_ip:  $head_ip
opencontrail_webui_ip:      $head_ip

customize_etc_hosts: False
computes_need_external_bridge: False

nova_compute_virt_type: $virt
openstack_service_workers: "1"
EOF


cat > /etc/kayobe/tf.yml << EOF
provider_config:
  bms:
    domainsuffix: local
instances:
EOF
for name in `nodeattr -n head`; do
cat >> /etc/kayobe/tf.yml << EOF
  $name:
    provider: bms
    ip: $(resolve_host $name)
    roles:
      config_database:
      config:
      control:
      analytics_database:
      analytics:
      webui:
      openstack:
EOF
done
for name in `nodeattr -n compute`; do
cat >> /etc/kayobe/tf.yml << EOF
  $name:
    provider: bms
    ip: $(resolve_host $name)
    roles:
      vrouter:
      openstack_compute:
EOF
done

cat >> /etc/kayobe/tf.yml << EOF
global_configuration:
#  CONTAINER_REGISTRY: tungstenfabric
  CONTAINER_REGISTRY: $rhost:$rport
  REGISTRY_PRIVATE_INSECURE: True
contrail_configuration:
  CLOUD_ORCHESTRATOR: openstack
  OPENSTACK_VERSION: $os
  CONTRAIL_VERSION: $tf
  AUTH_MODE: keystone
  KEYSTONE_AUTH_URL_VERSION: /v3
kolla_config:
  kolla_passwords:
    keystone_admin_password: admin
    metadata_secret: contrail
  kolla_globals:
    neutron_plugin_agent: opencontrail
    enable_opencontrail_rbac: no
    contrail_dm_integration: False
    neutron_type_drivers: "local,vlan,gre,vxlan"
    neutron_tenant_network_types: "local,vlan"
    enable_haproxy: False
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
kolla_enable_heat: true
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
kolla_enable_openvswitch: false
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
