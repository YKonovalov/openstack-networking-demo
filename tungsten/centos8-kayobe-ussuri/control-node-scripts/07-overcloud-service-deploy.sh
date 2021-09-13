#!/bin/sh
set -e

source ~/kayobe.venv

echo "FIXME5: Stopping tungsten rabbit to free epmd (TCP:4369) port, otherwise kayobe will fail"
pdsh -g head docker stop config_database_rabbitmq_1

kayobe overcloud service deploy

echo "FIXME5: Starting tungsten rabbit that we stopped earlier"
pdsh -g head docker start config_database_rabbitmq_1

echo "FIXME6: tungsten nova-compute driver execs python script with unversioned python shebang"
kayobe -v overcloud host command run --become --limit compute --command "docker exec  -u root nova_compute alternatives --set python /usr/bin/python3"
