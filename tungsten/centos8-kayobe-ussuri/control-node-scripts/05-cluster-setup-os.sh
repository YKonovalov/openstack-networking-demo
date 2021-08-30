#!/bin/sh

unset SSH_AUTH_SOCK

tlog() {
  \time -f "%E %C (exit code: %X)" -a -o /tmp/tlog $@
}

time (
  source ~/kayobe.rc
  tlog kayobe overcloud service deploy

  echo "FIXME5: Starting tungsten rabbit that we stopped earlier"
  pdsh -g head docker start config_database_rabbitmq_1

  echo "FIXME6: tungsten nova-compute driver execs python script with unversioned python shebang"
  pdsh -g compute 'docker exec  -u root nova_compute alternatives --set python /usr/bin/python3'

  echo "FIXME7: vrouter_provisioner failed to properly register vrouter on first run (missing ContrailConfig, fabric routes, etc) TODO: when fabric ip cidr is not /24?"
  pdsh -g compute docker restart vrouter_provisioner_1
)
