#!/bin/sh

unset SSH_AUTH_SOCK

dockerFixLocalRegistry() {
  rhost="$(nodeattr -n build|head -1)"
  rport="$(nodeattr -v build0 docker_registry_listen_port)"
cat > /tmp/daemon.json << EOF
{
    "insecure-registries": [
        "$rhost:$rport"
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
  pdcp -g head,compute /tmp/daemon.json /etc/docker/daemon.json
  pdsh -g head,compute systemctl restart docker
}

tlog() {
  \time -f "%E %C (exit code: %X)" -a -o /tmp/tlog $@
}

time (
  echo "FIXME4: We should switch to our own docker resistry in kolla as well. Then we can remove this hack."
  dockerFixLocalRegistry

  source ~/venvs/kolla-ansible/bin/activate
  tlog ansible-playbook -i /etc/kayobe/inventory \
    -e config_file=/etc/kayobe/tf.yml \
    -e ansible_python_interpreter=/opt/kayobe/venvs/kolla-ansible/bin/python \
    ~/src/tf-ansible-deployer/playbooks/install_contrail.yml
  deactivate

  echo "FIXME2: Change iface name to vhost0, otherwise kolla-ansible will fail to find host ip"
  sed -i "s/common_interface: .*/common_interface: vhost0/" /etc/kayobe/inventory/group_vars/compute/network-interfaces
)
