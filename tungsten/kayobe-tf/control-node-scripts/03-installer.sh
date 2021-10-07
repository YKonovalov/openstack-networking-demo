#!/bin/sh

. ~/kayobe.env

chost="$(nodeattr -n control|head -1)"
os="$(nodeattr -v $chost os)"
tf="$(nodeattr -v $chost tf)"
virt="$(nodeattr -v $chost virt)"

os="${os:-ussuri}"
tf="${tf:-dev}"
virt="${virt:-kvm}"

. /etc/os-release
case $ID in
  ubuntu)
    pdsh -a 'apt -y install git python3-virtualenv python3-docker python3-dev libffi-dev gcc libssl-dev time jq mc'
    venv=virtualenv
    ;;
  centos)
    # wallaby requires centos stream
    pdsh -a 'rpm -e pdsh-mod-nodeupdown'
    pdsh -a 'dnf -y install centos-release-stream --allowerasing'
    pdsh -a 'dnf -y swap centos-{linux,stream}-repos'
    pdsh -a 'dnf -y distro-sync'

    dnf -y install git python3-virtualenv python3-devel libffi-devel gcc openssl-devel python3-libselinux python3-dnf time jq
    dnf -y install centos-release-openstack-ussuri
    dnf -y install python3-openstackclient python3-heatclient
    venv=virtualenv-3

    export PDSH_SSH_ARGS_APPEND='-o StrictHostKeyChecking=no'
    pdsh -a 'dnf -y install lsof jq python3-virtualenv python3-dnf'
    pdsh -a 'dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo'
    pdsh -a 'dnf -y install docker-ce python3-docker'
    ;;
  *)
    ;;
esac

cd
mkdir -p $SRC ||:

[ -d "$KAYOBE_SOURCE_PATH" ] ||
  git clone https://github.com/openstack/kayobe.git -b stable/$os "$KAYOBE_SOURCE_PATH"

[ -d "$TF_SOURCE_PATH" ] ||
  git clone https://github.com/tungstenfabric/tf-ansible-deployer.git -b master "$TF_SOURCE_PATH"


[ -d "$KAYOBE_VENV_PATH" ] || (
$venv "$KAYOBE_VENV_PATH"
source "$KAYOBE_VENV_PATH/bin/activate"
 pip install -U pip
 pip install "$KAYOBE_SOURCE_PATH"
deactivate
)
