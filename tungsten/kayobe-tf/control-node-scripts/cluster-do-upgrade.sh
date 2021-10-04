#!/bin/sh

D=`dirname $0`

if [ -f ~/kayobe.env ]; then
  os="$(nodeattr -v $chost os)"
  os="${os:-wallaby}"
  case "$os" in
  ussuri)
    newos=victoria
    ;;
  victoria)
    newos=wallaby
    ;;
  *)
    echo "Do not know how to upgrae $os"
    exit 2
    ;;
  esac
  sed -i "s/os=$os/os=$newos/" /etc/genders
  tar cf $os.logs.tar /root/*.log /tmp/tlog
  (. ~/kayobe.env; rm -rf "$SRC" "$VENVS")
  sh "$D/cluster-do-setup.sh"
else
  echo "No previous version found"
  exit 1
fi
