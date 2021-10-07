#!/bin/sh

. ~/kayobe.env

resolve_host() {
  getent ahostsv4 $1|head -1|cut -d ' ' -f1
}


chost="$(nodeattr -n control|head -1)"
os="$(nodeattr -v $chost os)"
tf="$(nodeattr -v $chost tf)"
virt="$(nodeattr -v $chost virt)"
iface="$(nodeattr -v $chost iface)"
tfcustom="$(nodeattr -v $chost tfcustom && echo True || echo False)"
cacheimages="$(nodeattr -v $chost cacheimages && echo True || echo False)"

os="${os:-wallaby}"
tf="${tf:-latest}"
virt="${virt:-kvm}"
iface="${iface:-eth0}"

hhost="$(nodeattr -n head|head -1)"
head_ip=$(resolve_host $hhost)

docker_registry=""
if [ "$cacheimages" == "True" ]; then
  docker_registry="$chost:4000"
fi

tf_docker_registry="$docker_registry"
tf_namespace=
if [ "$tfcustom" == "True" ]; then
  rhost="$(nodeattr -n build|head -1)"
  rport="$(nodeattr -v $rhost docker_registry_listen_port)"
  tf_docker_registry="$rhost:$rport"
else
  tf_namespace=tungstenfabric
fi


mkdir -p "$KAYOBE_CONFIG_PATH/inventory/group_vars/"{seed,controllers,compute,overcloud} "$KAYOBE_CONFIG_PATH/kolla"

cat > "$KAYOBE_CONFIG_PATH/inventory/groups" << EOF
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

[docker-registry:children]
seed

[container-image-builders:children]
seed

[ntp:children]
seed
overcloud

# we don't use network group yet, but playbooks fail unless we define it:
[network:children]
controllers
[storage]
[monitoring]
EOF

cat > "$KAYOBE_CONFIG_PATH/network-allocation.yml" << EOF
common_ips:
`nodeattr -n "control||head||compute"|while read name; do echo " $name: $(resolve_host $name)"; done`
EOF

cat > "$KAYOBE_CONFIG_PATH/inventory/hosts" << EOF
localhost ansible_connection=local config_file=../tf.yml
[seed]
$chost ansible_connection=local
EOF

cat > "$KAYOBE_CONFIG_PATH/inventory/overcloud" << EOF
[controllers]
`nodeattr -n head   |awk '{print $0, "ansible_host="$0}'`
[compute]
`nodeattr -n compute|awk '{print $0, "ansible_host="$0}'`
EOF

tee "$KAYOBE_CONFIG_PATH/inventory/group_vars"/{seed,controllers}/network-interfaces << EOF
common_interface: $iface
common_bootproto: static
EOF
cat > "$KAYOBE_CONFIG_PATH/inventory/group_vars/compute/network-interfaces" << EOF
common_interface: vhost0
common_bootproto: static
EOF

tee "$KAYOBE_CONFIG_PATH/inventory/group_vars"/{seed,overcloud}/ansible_python_interpreter << EOF
ansible_python_interpreter: "{{ virtualenv_path }}/kayobe/bin/python"
EOF

cat >  "$KAYOBE_CONFIG_PATH/networks.yml" << EOF
admin_oc_net_name:                   common
oob_oc_net_name:                     common
oob_wl_net_name:                     common
provision_oc_net_name:               common
provision_wl_net_name:               common
inspection_net_name:                 common
cleaning_net_name:                   common
external_net_names:                 [common]
public_net_name:                     common
internal_net_name:                   common
tunnel_net_name:                     common
storage_mgmt_net_name:               common
storage_net_name:                    common
swift_storage_net_name:              common
swift_storage_replication_net_name:  common
EOF

cat >  "$KAYOBE_CONFIG_PATH/networks-common.yml" << EOF
common_cidr: $(ip -j r s dev $iface scope link|jq -r '.[0]|.dst')
common_gateway: $(ip -j r s dev $iface default|jq -r '.[0]|.gateway')
common_fqdn: $head_ip
common_vip_address: $head_ip
EOF

cat > "$KAYOBE_CONFIG_PATH/dns.yml" << EOF
resolv_is_managed: True
resolv_nameservers:
  - 8.8.8.8
  - 8.8.4.4
EOF

cat > "$KAYOBE_CONFIG_PATH/time.yml" << EOF
timezone: Europe/Moscow
chrony_ntp_servers:
  - server: pool.ntp.org
    type: pool
    options:
      - option: maxsources
        val: 3
EOF

cat > "$KAYOBE_CONFIG_PATH/hosts-vars.yml" << EOF
disable-glean: true
seed_lvm_groups: []
controller_lvm_groups: []
compute_lvm_groups: []
EOF

cat > "$KAYOBE_CONFIG_PATH/docker.yml" << EOF
docker_storage_driver: overlay2
docker_daemon_live_restore: true
tf_docker_registry: "$tf_docker_registry"
kolla_docker_custom_config: "{{ ({'insecure-registries':[tf_docker_registry]} if tf_docker_registry else {}) | combine({'registry-mirrors':docker_registry_mirrors} if docker_registry_mirrors else {}) }}"
EOF

if [ "$cacheimages" == "True" ]; then
cat > "$KAYOBE_CONFIG_PATH/docker-registry.yml" << EOF
docker_registry_enabled: true
docker_registry_port: 4000
docker_registry_datadir_volume: "/opt/registry"
docker_registry_env:
  REGISTRY_PROXY_REMOTEURL: "https://registry-1.docker.io"
docker_registry_mirrors:
  - "http://$docker_registry/"
EOF
fi

cat > "$KAYOBE_CONFIG_PATH/kolla.yml" << EOF
bootstrap_user: "root"
openstack_release: $os
openstack_branch: stable/$os
#kolla_ansible_source_url: https://github.com/tungstenfabric/tf-kolla-ansible.git
kolla_ansible_source_url: https://github.com/YKonovalov/tf-kolla-ansible
kolla_ansible_source_version: contrail/$os
kolla_ansible_venv_extra_requirements: [docker-compose]
kolla_ansible_custom_passwords:
 keystone_admin_password: admin
 metadata_secret: contrail
 kolla_ssh_key:
  private_key: "{{ lookup('file', ssh_private_key_path) }}"
  public_key: "{{ lookup('file', ssh_public_key_path) }}"
kolla_enable_neutron_provider_networks: False
kolla_enable_heat: true
EOF

cat > "$KAYOBE_CONFIG_PATH/kolla/globals.yml" << EOF
tf_tag: "$tf"
tf_namespace: "$tf_namespace"
tf_docker_registry: "{{ tf_docker_registry }}"

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


cat > "$KAYOBE_CONFIG_PATH/tf.yml" << EOF
provider_config:
  bms:
    domainsuffix: local
instances:
EOF
for name in `nodeattr -n head`; do
cat >> "$KAYOBE_CONFIG_PATH/tf.yml" << EOF
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
cat >> "$KAYOBE_CONFIG_PATH/tf.yml" << EOF
  $name:
    provider: bms
    ip: $(resolve_host $name)
    roles:
      vrouter:
      openstack_compute:
EOF
done

cat >> "$KAYOBE_CONFIG_PATH/tf.yml" << EOF
global_configuration:
  CONTAINER_REGISTRY: $(echo $tf_docker_registry $tf_namespace|tr ' ' '/')
  REGISTRY_PRIVATE_INSECURE: $tfcustom
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

cat > "$KAYOBE_CONFIG_PATH/kolla-disabled.yml" << EOF
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
