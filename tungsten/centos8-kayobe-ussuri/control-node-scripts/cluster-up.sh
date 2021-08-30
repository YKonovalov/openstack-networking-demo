#!/bin/sh

unset SSH_AUTH_SOCK

echo "Waiting for /etc/kolla/admin-openrc.sh"
F=/etc/kolla/admin-openrc.sh
while true; do
  if [ -f /etc/kolla/admin-openrc.sh ]; then
    echo "All done"
    break
  else
     sleep 10
  fi
done
