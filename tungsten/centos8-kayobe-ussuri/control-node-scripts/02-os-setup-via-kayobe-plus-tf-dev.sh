#!/bin/sh
. ./config.sh
. ./common/functions.sh

# on the kayobe control host
dnf -y install python3-devel libffi-devel gcc openssl-devel python3-libselinux time jq
dnf -y install centos-release-openstack-ussuri
dnf -y install python3-openstackclient python3-heatclient
on-all 'dnf -y install lsof jq python3-virtualenv'
on-all 'dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo'
on-all 'dnf -y install docker-ce --nobest'
#
# pdsh -w head,compute[1-3] 'cat /root/.ssh/authorized_keys >> /home/kolla/.ssh/authorized_keys'
#
cd
mkdir src
head_ip=$(dig +short head A)
compute1_ip=$(dig +short compute1 A)
compute2_ip=$(dig +short compute2 A)
compute3_ip=$(dig +short compute3 A)

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

# FIXME we need to have similar venvs paths as on target hosts for tungsten playbooks run
if ! [ -L /opt/kayobe/venvs ]; then
  mkdir -p /opt/kayobe
  ln -fs /root/venvs /opt/kayobe/venvs
fi

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
 head: $head_ip
 compute1: $compute1_ip
 compute2: $compute2_ip
 compute3: $compute3_ip
common_fqdn: head.
common_vip_address: $head_ip
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
#kolla_ansible_source_url: https://github.com/tungstenfabric/tf-kolla-ansible.git
kolla_ansible_source_url: https://github.com/YKonovalov/tf-kolla-ansible
kolla_ansible_source_version: contrail/$OS
#kolla_ansible_user: root
kolla_ansible_custom_passwords:
 keystone_admin_password: admin
 metadata_secret: contrail
 kolla_ssh_key:
  private_key: "{{ lookup('file', ssh_private_key_path) }}"
  public_key: "{{ lookup('file', ssh_public_key_path) }}"
kolla_enable_neutron_provider_networks: False
#kolla_neutron_ml2_mechanism_drivers: [opencontrail]
#kolla_neutron_ml2_type_drivers: [geneve]
#kolla_neutron_ml2_tenant_network_types: [geneve]
#kolla_neutron_ml2_extension_drivers: [port_security]
kolla_enable_heat: true
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

#metadata_secret: contrail
neutron_plugin_agent: opencontrail
#neutron_plugin_agent: opencontrail-ml2
neutron_fwaas_version: v2

opencontrail_api_server_ip: $head_ip
opencontrail_collector_ip:  $head_ip
opencontrail_webui_ip:      $head_ip

customize_etc_hosts: False
computes_need_external_bridge: False
EOF

cat > /etc/kayobe/dns.yml << EOF
resolv_is_managed: false
EOF

cat > /etc/kayobe/tf.yml << EOF
provider_config:
  bms:
    domainsuffix: local
instances:
  head:
    provider: bms
    ip: $head_ip
    roles:
      config_database:
      config:
      control:
      analytics_database:
      analytics:
      webui:
      openstack:
  compute1:
    provider: bms
    ip: $compute1_ip
    roles:
      vrouter:
      openstack_compute:
  compute2:
    provider: bms
    ip: $compute2_ip
    roles:
      vrouter:
      openstack_compute:
  compute3:
    provider: bms
    ip: $compute3_ip
    roles:
      vrouter:
      openstack_compute:
global_configuration:
#  CONTAINER_REGISTRY: tungstenfabric
  CONTAINER_REGISTRY: build:5000
  REGISTRY_PRIVATE_INSECURE: True
contrail_configuration:
  CLOUD_ORCHESTRATOR: openstack
  OPENSTACK_VERSION: $OS
  CONTRAIL_VERSION: dev
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
    enable_heat: yes
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
    enable_openvswitch: no
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

cat > /tmp/heat.yaml << \EOF
heat_template_version: 2018-08-31
description: SDN demo set of resources heat template
resources:
  net1:
    type: OS::Neutron::Net
    properties:
      name: net1
  net1-v4:
    type: OS::Neutron::Subnet
    properties:
      name: net1-v4
      network_id: { get_resource: net1 }
      cidr: 10.0.1.0/24

  net2:
    type: OS::Neutron::Net
    properties:
      name: net2
  net2-v4:
    type: OS::Neutron::Subnet
    properties:
      name: net2-v4
      network_id: { get_resource: net2 }
      cidr: 10.0.2.0/24

  net1ers:
    type: OS::Nova::ServerGroup
    properties:
      name: net1ers
      policies: [anti-affinity]
  net2ers:
    type: OS::Nova::ServerGroup
    properties:
      name: net2ers
      policies: [anti-affinity]

  net1-a:
    type: OS::Nova::Server
    properties:
      name: net1-a
      image: cirros2
      flavor: m1.tiny
      networks:
      - network: { get_resource: net1 }
      scheduler_hints:
        group: { get_resource: net1ers }
  net1-b:
    type: OS::Nova::Server
    properties:
      name: net1-b
      image: cirros2
      flavor: m1.tiny
      networks:
      - network: { get_resource: net1 }
      scheduler_hints:
        group: { get_resource: net1ers }
  net1-c:
    type: OS::Nova::Server
    properties:
      name: net1-c
      image: cirros2
      flavor: m1.tiny
      networks:
      - network: { get_resource: net1 }
      scheduler_hints:
        group: { get_resource: net1ers }

  net2-a:
    type: OS::Nova::Server
    properties:
      name: net2-a
      image: cirros2
      flavor: m1.tiny
      networks:
      - network: { get_resource: net2 }
      scheduler_hints:
        group: { get_resource: net2ers }

  net2-b:
    type: OS::Nova::Server
    properties:
      name: net2-b
      image: cirros2
      flavor: m1.tiny
      networks:
      - network: { get_resource: net2 }
      scheduler_hints:
        group: { get_resource: net2ers }
  net2-c:
    type: OS::Nova::Server
    properties:
      name: net2-c
      image: cirros2
      flavor: m1.tiny
      networks:
      - network: { get_resource: net2 }
      scheduler_hints:
        group: { get_resource: net2ers }

outputs:
  server_networks:
    description: The networks of the deployed server
    value: { get_attr: [net1-a, networks] }
EOF

openstackResourcesAddHeat(){
  openstack service list
  curl -OL --progress http://download.cirros-cloud.net/0.5.1/cirros-0.5.1-x86_64-disk.img
  cat cirros-0.5.1-x86_64-disk.img|openstack image create cirros2 --disk-format qcow2 --public --container-format bare
  openstack flavor create --public m1.tiny --id auto --ram 1024 --disk 10
  openstack stack create -t /tmp/heat.yaml tf-demo
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
cat > /tmp/networkd-disable-ip-on-eth0-when-vhost0.service << \EOF
[Unit]
Description=Disable dhcp on eth0 when vhost0 appear
Requires=systemd-networkd.service
After=sys-subsystem-net-devices-vhost0.device

[Service]
ExecStart=/usr/bin/sh -c '/usr/lib/systemd/systemd-networkd-wait-online -i vhost0 && (rm -f /etc/systemd/network/80-eth0.network && /usr/bin/networkctl reload)'

[Install]
Also=systemd-networkd-wait-online.service
EOF

  cp-compute /tmp/ifcfg-eth0 /etc/sysconfig/network-scripts/ifcfg-eth0
  cp-compute /tmp/networkd-disable-ip-on-eth0-when-vhost0.service /etc/systemd/system/
  on-compute systemctl daemon-reload
  on-compute systemctl enable --now networkd-disable-ip-on-eth0-when-vhost0.service
  on-all 'ln -fs /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf'
  if [ -n "$1" ]; then
    cp-compute /tmp/ifcfg-vhost0 /etc/sysconfig/network-scripts/ifcfg-vhost0
  fi
  on-compute 'networkctl reload'
}

dockerFixLocalRegistry() {
cat > /tmp/daemon.json << \EOF
{
    "insecure-registries": [
        "build:5000"
    ],
    "live-restore": true,
    "log-opts": {
        "max-file": "5",
        "max-size": "50m"
    },
    "mtu": 1500,
    "storage-driver": "overlay",
    "storage-opts": []
}
EOF
  cp-all /tmp/daemon.json /etc/docker/daemon.json
  on-all systemctl restart docker
}

rm -f /tmp/tlog
alias tlog='\time -f "%E %C (exit code: %X)" -a -o /tmp/tlog'
time (
  networkSetConf

  # FIXME1: Change iface name to eth0, otherwise kolla-ansible will fail to find host ip
  sed -i "s/common_interface: .*/common_interface: eth0/" /etc/kayobe/inventory/group_vars/compute/network-interfaces

  source ~/kayobe.rc
  tlog kayobe   control host bootstrap
  tlog kayobe overcloud host configure

  # FIXME2: should be installed by 'kayobe overcloud host configure'
  on-all '/opt/kayobe/venvs/kolla-ansible/bin/pip install docker-compose'

  # FIXME3: We should switch to our own docker resistry in kolla as well. Then we can remove this hack.
  dockerFixLocalRegistry

  tlog ansible-playbook -i /etc/kayobe/inventory \
    -e config_file=/etc/kayobe/tf.yml \
    -e ansible_python_interpreter=/opt/kayobe/venvs/kolla-ansible/bin/python \
    src/tf-ansible-deployer/playbooks/install_contrail.yml

  # FIXME3: Stopping tungsten rabbit to free epmd (TCP:4369) port, otherwise kayobe will fail
  on-head docker stop config_database_rabbitmq_1

  # FIXME1: Change iface name to vhost0, otherwise kolla-ansible will fail to find host ip
  sed -i "s/common_interface: .*/common_interface: vhost0/" /etc/kayobe/inventory/group_vars/compute/network-interfaces

  source ~/kayobe.rc
  tlog kayobe overcloud service deploy

  # FIXME4: Starting tungsten rabbit that we stopped earlier
  on-head docker start config_database_rabbitmq_1

  # FIXME5: tungsten nova-compute driver execs python script with unversioned python shebang
  on-compute 'docker exec  -u root nova_compute alternatives --set python /usr/bin/python3'

  . /etc/kolla/admin-openrc.sh
  time openstackResourcesAddHeat

  cat /tmp/tlog
)
