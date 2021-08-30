#!/bin/sh
D=`dirname $0`

S="
01-cluster-configure.sh
02-cluster-setup-code.sh
03-cluster-setup-hosts.sh
04-cluster-setup-tf.sh
05-cluster-setup-os.sh
06-cluster-resources.sh
"

unset SSH_AUTH_SOCK

dolog(){
  sh "$D/$1" 2>&1 | tee "$(basename -s .sh "$1").log"
}

for s in $S; do
 if ! dolog $s; then
   e=$?
   echo "ERROR: $s exits with error code: $e" >&2
   exit $e
 fi
done

cat /tmp/tlog
