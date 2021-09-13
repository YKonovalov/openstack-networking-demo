#!/bin/sh

rm -f ~/kayobe.{,v}env

cat > ~/kayobe.env << \EOF
SRC=/opt/kayobe/src
SRC="$HOME/src"

VENVS=/opt/kayobe/venvs
VENVS="$HOME/venvs"

export KAYOBE_CONFIG_ROOT=/opt/kayobe/src/kayobe-config-$STAND
export KAYOBE_CONFIG_ROOT=/

ETC="$(echo $KAYOBE_CONFIG_ROOT/etc|sed "s;//;/;g")"

export KAYOBE_CONFIG_SOURCE_PATH="$HOME"

export KAYOBE_CONFIG_PATH="$ETC/kayobe"
export KAYOBE_SOURCE_PATH="$SRC/kayobe"
export KAYOBE_VENV_PATH="$VENVS/kayobe"

export KOLLA_CONFIG_PATH="$ETC/kolla"
export KOLLA_SOURCE_PATH="$SRC/kolla-ansible"
export KOLLA_VENV_PATH="$VENVS/kolla-ansible"

export TF_CONFIG_PATH="$KAYOBE_CONFIG_PATH/tf.yml"
export TF_SOURCE_PATH="$SRC/tf-ansible-deployer"
export TF_VENV_PATH="$KOLLA_VENV_PATH"

#export KAYOBE_CONFIG_PATH="/etc/kayobe"
#export KOLLA_CONFIG_PATH="/etc/kolla"

export KAYOBE_DATA_FILES_PATH="$KAYOBE_SOURCE_PATH"

unset SSH_AUTH_SOCK

resolve_host() {
  getent hosts $1|head -1|cut -d ' ' -f1
}
EOF

cat > ~/kayobe.venv << \EOF
source ~/kayobe.env
echo "Using Kayobe config from $KAYOBE_CONFIG_ROOT"
source "$KAYOBE_VENV_PATH/bin/activate"
EOF
