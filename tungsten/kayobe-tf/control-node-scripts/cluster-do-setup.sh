#!/bin/sh

D=`dirname $0`

S="
01-env.sh
02-configure.sh
03-installer.sh
04-control-host-bootstrap.sh
05-overcloud-host.sh
06-tf.sh
07-overcloud-service-deploy.sh
08-resources-basic.sh
09-resources-demo.sh
"

unset SSH_AUTH_SOCK

dolog(){
  cmd="bash "$D/$1" 2>&1 | tee "$(basename -s .sh "$1")$2.log""
  \time -f "%E %C (exit code: %x)" -a -o /tmp/tlog sh -eo pipefail -c "$cmd"
}

rm -f /tmp/tlog
for s in $S; do
 if ! dolog $s; then
   e=$?
   echo "ERROR: $s exits with error code: $e" >&2
   echo "Retrying one more time..."
   if ! dolog $s ".retry"; then
     e=$?
     echo "FATAL: $s exits with error code second time: $e" >&2
     exit $e
   fi
 fi
done

cat /tmp/tlog
