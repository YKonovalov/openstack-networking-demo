#!/bin/sh

###
## OpenStack version codename to install (e.g. train for example)
#
OS=ussuri

unset SSH_AUTH_SOCK

# on the kayobe control host
dnf -y install python3-virtualenv python3-devel libffi-devel gcc openssl-devel python3-libselinux time jq
dnf -y install centos-release-openstack-ussuri
dnf -y install python3-openstackclient python3-heatclient

export PDSH_SSH_ARGS_APPEND='-o StrictHostKeyChecking=no'
pdsh -g head,compute 'dnf -y install lsof jq python3-virtualenv'
pdsh -g head,compute 'dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo'
pdsh -g head,compute 'dnf -y install docker-ce --nobest'

cd
mkdir src

[ -d ~/src/kayobe ] || (
 git clone https://github.com/openstack/kayobe.git -b stable/$OS ~/src/kayobe
 empty_match="\(^#\|---\|^$\|workaround_ansible_issue_8743: yes\)"
 sed -i "/$empty_match/ d" ~/src/kayobe/ansible/roles/kolla-ansible/templates/globals.yml.j2
 sed -i "/neutron_plugin_agent/ d" ~/src/kayobe/ansible/roles/kolla-ansible/templates/globals.yml.j2
)

[ -d ~/src/tf-ansible-deployer ] ||
 git clone https://github.com/tungstenfabric/tf-ansible-deployer.git -b master src/tf-ansible-deployer


[ -d ~/venvs/kayobe ] || (
virtualenv-3 ~/venvs/kayobe
source ~/venvs/kayobe/bin/activate
 pip install -U pip
 pip install src/kayobe
deactivate
)

echo "FIXME1: we need to have similar venvs paths as on target hosts for tungsten playbooks run"
if ! [ -L /opt/kayobe/venvs ]; then
  mkdir -p /opt/kayobe
  ln -fs /root/venvs /opt/kayobe/venvs
fi

cat > ~/kayobe.rc << EOF
export KAYOBE_CONFIG_PATH="/etc/kayobe"
export KOLLA_CONFIG_PATH="/etc/kolla"

export KAYOBE_DATA_FILES_PATH="$(realpath ~/src/kayobe          )"
export KOLLA_SOURCE_PATH="$(realpath      ~/src/kolla-ansible   )"

export KAYOBE_VENV_PATH="$(realpath      ~/venvs/kayobe         )"
export KOLLA_VENV_PATH="$(realpath        ~/venvs/kolla-ansible )"

source "\$KAYOBE_VENV_PATH/bin/activate"
#cd "\$KAYOBE_DATA_FILES_PATH"
EOF
