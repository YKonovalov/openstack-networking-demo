git clone https://github.com/tungstenfabric/tf-ansible-deployer
cd tf-ansible-deployer

cat > config/instances.yaml << EOF
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
contrail_configuration:
  CLOUD_ORCHESTRATOR: openstack
  OPENSTACK_VERSION: train
  CONTRAIL_VERSION: latest
  AUTH_MODE: keystone
  KEYSTONE_AUTH_URL_VERSION: /v3
kolla_config:
  kolla_passwords:
    keystone_admin_password: admin
  customize:
    nova.conf: |
      [libvirt]
      virt_type=qemu
      cpu_mode=none
  kolla_globals:
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
ansible-playbook -i inventory/ playbooks/configure_instances.yml
virtualenv venv
. venv/bin/activate
pip install ../contrail-kolla-ansible
pip install ansible
ansible-playbook -i inventory/ playbooks/install_openstack.yml
ansible-playbook -i inventory/ playbooks/install_contrail.yml

scp kolla:/etc/kolla/kolla-toolbox/admin-openrc.sh ./
. admin-openrc.sh
openstack image show cirros >/dev/null 2>&1 || (
  curl -OL --progress http://download.cirros-cloud.net/0.5.1/cirros-0.5.1-x86_64-disk.img
  openstack image create cirros2 --disk-format qcow2 --public --container-format bare --file cirros-0.5.1-x86_64-disk.img
)
openstack flavor create --public m1.tiny --id auto --ram 1024 --disk 10
while read net cidr; do
  netid="$(openstack network create --share $net -c id -f value)"; [ -n "$netid" ]
  openstack subnet create --network $net --ip-version 4 --subnet-range $cidr $net-v4

  for name in a b c; do
    openstack server create --flavor m1.tiny --image cirros2 --network=$netid $net-$name
  done
done << EOF
pub-a 192.168.168.0/24
pub-b 192.168.169.0/24
pub-c 192.168.170.0/24
pub-d 192.168.100.0/24"
EOF
