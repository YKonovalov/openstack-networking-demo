#!/bin/sh
set -e

source ~/kayobe.venv

kayobe overcloud service upgrade

echo "FIXME6: tungsten nova-compute driver execs python script with unversioned python shebang"
kayobe -v overcloud host command run --become --limit compute --command "docker exec  -u root nova_compute alternatives --set python /usr/bin/python3"
