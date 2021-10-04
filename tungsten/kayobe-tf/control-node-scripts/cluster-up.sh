#!/bin/sh

unset SSH_AUTH_SOCK

echo "Waiting for /etc/kolla/admin-openrc.sh"
echo "Please note it normally takes half an hour or more. At this stage you can safely stop terraform and run this command again later to see status of deploy."
F=/etc/kolla/admin-openrc.sh
while true; do
  if [ -f /etc/kolla/admin-openrc.sh ]; then
    echo "All done"
    cat /tmp/tlog
    echo "Next is a check for failed or unreachable ansible status (one unreachable in 05-seed-create.log is expected):"
    echo --------
    grep ok= [0-9]*.log|grep '\(unreachable\|failed\)=[1-9]'
    echo --------
    break
  elif ! pgrep -f 'control-node-scripts/cluster-do-setup.sh' >/dev/null; then
    echo "ERROR: script exited:"
    cat /tmp/tlog
    grep ok= ~/[0-9]*.log|grep '\(unreachable\|failed\)=[1-9]'
    exit 1
  else
    sleep 10
  fi
done
