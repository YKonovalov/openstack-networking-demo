#!/bin/sh

. ~/kayobe.env

chost="$(nodeattr -n control|head -1)"
os="$(nodeattr -v $chost os)"
tf="$(nodeattr -v $chost tf)"
virt="$(nodeattr -v $chost virt)"

os="${os:-ussuri}"
tf="${tf:-dev}"
virt="${virt:-kvm}"

# wallaby requires centos stream
pdsh -a 'rpm -e pdsh-mod-nodeupdown'
pdsh -a 'dnf -y install centos-release-stream --allowerasing'
pdsh -a 'dnf -y swap centos-{linux,stream}-repos'
pdsh -a 'dnf -y distro-sync'

dnf -y install python3-virtualenv python3-devel libffi-devel gcc openssl-devel python3-libselinux time jq
dnf -y install centos-release-openstack-ussuri
dnf -y install python3-openstackclient python3-heatclient

export PDSH_SSH_ARGS_APPEND='-o StrictHostKeyChecking=no'
pdsh -g head,compute 'dnf -y install lsof jq python3-virtualenv'
pdsh -g head,compute 'dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo'
pdsh -g head,compute 'dnf -y install docker-ce python3-docker'

cd
mkdir -p $SRC ||:

[ -d "$KAYOBE_SOURCE_PATH" ] ||
  git clone https://github.com/openstack/kayobe.git -b stable/$os "$KAYOBE_SOURCE_PATH"

[ -d "$TF_SOURCE_PATH" ] ||
  git clone https://github.com/tungstenfabric/tf-ansible-deployer.git -b master "$TF_SOURCE_PATH"


[ -d "$KAYOBE_VENV_PATH" ] || (
virtualenv-3 "$KAYOBE_VENV_PATH"
source "$KAYOBE_VENV_PATH/bin/activate"
 pip install -U pip
 pip install ~/src/kayobe
deactivate
)

echo "FIXME1: we need to have similar venvs paths as on target hosts for tungsten playbooks run"
if ! [ -L /opt/kayobe/venvs ]; then
  mkdir -p /opt/kayobe
  ln -fs /root/venvs /opt/kayobe/venvs
fi
