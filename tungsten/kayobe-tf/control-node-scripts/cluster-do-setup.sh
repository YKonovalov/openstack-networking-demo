#!/bin/sh

D=`dirname $0`

ID=`date +%Y%m%d%H%M`
ME=`basename $0`
LOGD="$ME-$ID"
mkdir -p "$LOGD"

S="
01-env.sh
02-configure.sh
03-installer.sh
04-control-host-bootstrap.sh
05-seed-host-configure.sh
06-overcloud-host.sh
07-tf.sh
08-overcloud-service-deploy.sh
10-resources-basic.sh
11-resources-demo.sh
"

unset SSH_AUTH_SOCK

dolog(){
  cmd="bash "$D/$1" 2>&1 | tee "$LOGD/$(basename -s .sh "$1")$2.log""
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
