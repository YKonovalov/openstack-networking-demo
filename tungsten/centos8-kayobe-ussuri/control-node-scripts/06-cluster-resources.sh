#!/bin/sh

cloud_config() {
  cat /var/lib/cloud/instance/user-data.txt |
    python3 -c 'import sys, yaml, json; json.dump(yaml.load(sys.stdin), sys.stdout)' |
    jq -r 'with_entries(select(.key == "users"))' |
    python3 -c 'import sys, yaml, json; print(yaml.dump(json.loads(sys.stdin.read())))'
}

if C="$(cloud_config)" && [ -n "$C" ]; then
  C="$(echo -e "#cloud-config\n$C"|pr -to 8)"
  C="$(echo -e "|\n$C\n\n")"
else
  C=
fi

cat > /tmp/heat.yaml << EOF
heat_template_version: 2018-08-31
description: SDN demo set of resources heat template
resources:
  public:
    type: OS::Neutron::Net
    properties:
      name: public
      value_specs: {"router:external": true}
  public-v4:
    type: OS::Neutron::Subnet
    properties:
      name: public-v4
      network_id: { get_resource: public}
      cidr: $(getent hosts head0|head -1|cut -d ' ' -f1|awk -F. 'OFS="." {print $1,$2,$4,"0/24"}')

  internal:
    type: OS::Neutron::Net
    properties:
      name: internal
  internal-v4:
    type: OS::Neutron::Subnet
    properties:
      name: internal-v4
      network_id: { get_resource: internal }
      cidr: 10.0.0.0/24

  fip-int-a:
    depends_on: public
    type: OS::Neutron::FloatingIP
    properties:
      floating_network: { get_resource: public }
  fip-int-b:
    depends_on: public
    type: OS::Neutron::FloatingIP
    properties:
      floating_network: { get_resource: public }
  fip-int-c:
    depends_on: public
    type: OS::Neutron::FloatingIP
    properties:
      floating_network: { get_resource: public }

  port-int-a:
    type: OS::Neutron::Port
    properties:
      network: {get_resource: internal}
  port-int-b:
    type: OS::Neutron::Port
    properties:
      network: {get_resource: internal}
  port-int-c:
    type: OS::Neutron::Port
    properties:
      network: {get_resource: internal}

  publiciers:
    type: OS::Nova::ServerGroup
    properties:
      name: publiciers
      policies: [anti-affinity]
  internals:
    type: OS::Nova::ServerGroup
    properties:
      name: internals
      policies: [anti-affinity]

  key:
    type: OS::Nova::KeyPair
    properties:
      name: mykey
      public_key: ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDhnCbtsX8dsmLp5i2G9lDAsKM+05SqIh/kcer0sbv7K YKonovalov@gmail.com

  pub-a:
    type: OS::Nova::Server
    properties:
      name: pub-a
      image: cirros051
      flavor: m1.tiny
      key_name: { get_resource: key }
      user_data_format: RAW
      user_data: $C
      networks:
      - network: { get_resource: public }
      scheduler_hints:
        group: { get_resource: publiciers }
  pub-b:
    type: OS::Nova::Server
    properties:
      name: pub-b
      image: cirros051
      flavor: m1.tiny
      key_name: { get_resource: key }
      user_data_format: RAW
      user_data: $C
      networks:
      - network: { get_resource: public }
      scheduler_hints:
        group: { get_resource: publiciers }
  pub-c:
    type: OS::Nova::Server
    properties:
      name: pub-c
      image: fedora33
      flavor: m1.tiny
      key_name: { get_resource: key }
      user_data_format: RAW
      user_data: $C
      networks:
      - network: { get_resource: public }
      scheduler_hints:
        group: { get_resource: publiciers }

  int-a:
    type: OS::Nova::Server
    depends_on:
     - port-int-a
     - fip-int-a
    properties:
      name: int-a
      image: cirros051
      flavor: m1.tiny
      key_name: { get_resource: key }
      user_data_format: RAW
      user_data: $C
      networks:
      - port: { get_resource: port-int-a }
        floating_ip: { get_resource: fip-int-a }
      scheduler_hints:
        group: { get_resource: internals }

  int-b:
    type: OS::Nova::Server
    depends_on:
     - port-int-b
     - fip-int-b
    properties:
      name: int-b
      image: cirros051
      flavor: m1.tiny
      key_name: { get_resource: key }
      user_data_format: RAW
      user_data: $C
      networks:
      - port: { get_resource: port-int-b }
        floating_ip: { get_resource: fip-int-b }
      scheduler_hints:
        group: { get_resource: internals }
  int-c:
    type: OS::Nova::Server
    depends_on:
     - port-int-c
     - fip-int-c
    properties:
      name: int-c
      image: fedora33
      flavor: m1.tiny
      key_name: { get_resource: key }
      user_data_format: RAW
      user_data: $C
      networks:
      - port: { get_resource: port-int-c }
        floating_ip: { get_resource: fip-int-c }
      scheduler_hints:
        group: { get_resource: internals }

outputs:
  server_networks:
    description: The networks of the deployed server
    value: { get_attr: [pub-a, networks] }
EOF

openstackResourcesAddImageFlavor(){
  openstack service list
  curl -OL --progress http://download.cirros-cloud.net/0.5.1/cirros-0.5.1-x86_64-disk.img
  cat cirros-0.5.1-x86_64-disk.img|openstack image create cirros051 --disk-format qcow2 --public --container-format bare
  curl -OL --progress https://mirror.yandex.ru/fedora/linux/releases/33/Cloud/x86_64/images/Fedora-Cloud-Base-33-1.2.x86_64.qcow2
  cat Fedora-Cloud-Base-33-1.2.x86_64.qcow2|openstack image create fedora33 --disk-format qcow2 --public --container-format bare
  openstack flavor create --public m1.tiny --id auto --ram 1024 --disk 10
}

openstackResourcesAddHeat(){
  openstack stack create -t /tmp/heat.yaml tf-demo
}

time (
  . /etc/kolla/admin-openrc.sh
  time openstackResourcesAddImageFlavor
  time openstackResourcesAddHeat
)
