#!/bin/sh
cluster=compute
alias all='pdsh -w head,compute[1-3]'
alias head='pdsh -w head'
alias comp='pdsh -w compute[1-3]'
alias allcp='pdcp -w head,compute[1-3]'
comp_ip_list="$(echo $(awk -v m="$cluster.$" "\$3~m {print \$1}" /etc/hosts)|tr ' ' ',')"

yum -y install epel-release 
yum install -y python-pip
pip install requests
yum -y install git
pip install ansible==2.5.2.0

git clone http://github.com/Juniper/contrail-ansible-deployer

cat > contrail-ansible-deployer/config/instances.yaml << \EOF
provider_config:
  bms:
    domainsuffix: local
instances:
  head:
    provider: bms
    ip: 172.31.0.29
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
    ip: 172.31.0.17
    roles:
      vrouter:
      openstack_compute:
  compute2:
    provider: bms
    ip: 172.31.0.13
    roles:
      vrouter:
      openstack_compute:
  compute3:
    provider: bms
    ip: 172.31.0.10
    roles:
      vrouter:
      openstack_compute:
contrail_configuration:
  AUTH_MODE: keystone
  KEYSTONE_AUTH_URL_VERSION: /v3
kolla_config:
  kolla_globals:
    enable_haproxy: no
    enable_ironic: "no"
    enable_swift: "no"
  kolla_passwords:
    keystone_admin_password: admin
  customize:
    nova.conf: |
      [libvirt]
      virt_type=qemu
      cpu_mode=none
EOF

cd contrail-ansible-deployer
ansible-playbook -i inventory/ -e orchestrator=openstack playbooks/configure_instances.yml
ansible-playbook -i inventory/ playbooks/install_openstack.yml
ansible-playbook -i inventory/ -e orchestrator=openstack playbooks/install_contrail.yml
