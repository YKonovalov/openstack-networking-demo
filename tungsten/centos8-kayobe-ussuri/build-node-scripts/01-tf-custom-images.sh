#!/bin/sh
set -e

D=`dirname $0`
D=`readlink -e "$D"`

export tfbuild_custom_image=yes
export tfbuild_custom_image_maven_proxy=
export tfbuild_custom_image_sendbox_extra_cmd='yum makecache; yum -y install kernel-devel;unset no_proxy NO_PROXY; yum -y install https://vault.centos.org/8.3.2011/BaseOS/x86_64/os/Packages/kernel-{devel,headers}-4.18.0-240.10.1.el8_3.x86_64.rpm;for i in /usr/src/kernels/*; do t=/lib/modules/$(basename $i); [ -d $t ] || (mkdir $t && ln -s $i $t/build); done'

source "$D/common/functions-custimize-image.sh"

if [ "$tfbuild_custom_image" != "yes" ]; then
  exit
fi

image_present(){
  for i in $@; do
    if [ -z "$(docker image ls -q $i)" ]; then
      return 1
    fi
  done
}

#find /root/contrail -type f -name "Dockerfile" -exec sh -c 'a={}; echo $a $(grep FROM $a)|grep -v cni_go_deps|grep -v "{CONTRAIL_REGISTRY}"' \;
if image_present sandboxcentos:7 basecentos:7 basecentos:7.4.1708 baseubuntu:18.04; then
  exit
fi

for v in tfbuild_custom_image_maven_{proxy,user,pass} tfbuild_custom_image_files_{ssh,ca} tfbuild_custom_image_{http,https,no}_proxy; do
 if [ -z "$(eval "echo \$$v")" ]; then
   echo "E: $v var is required"
   #exit 1
 fi
done

TD="$(mktemp -d)"
if [ -n "$tfbuild_custom_image_files_ca" ]; then
  mkdir -p "$TD/etc/pki/ca-trust/source/anchors/"
  cp $tfbuild_custom_image_files_ca  "$TD/etc/pki/ca-trust/source/anchors/"
fi
if [ -n "$tfbuild_custom_image_files_dc" ]; then
  mkdir -p "$TD/root/.docker"
  cp $tfbuild_custom_image_files_dc  "$TD/root/.docker/"
fi
if [ -n "$tfbuild_custom_image_files_ssh" ]; then
  mkdir -p "$TD/root/.ssh/"
  cp $(eval "echo $tfbuild_custom_image_files_ssh") "$TD/root/.ssh/"
fi
if [ -n "$tfbuild_custom_image_ssh_keyscan_args" ]; then
  mkdir -p "$TD/root/.ssh/"
  ssh_keyscan > "$TD/root/.ssh/known_hosts"
fi
if [ -n "$tfbuild_custom_image_maven_proxy" ]; then
  mkdir -p "$TD/root/.m2/"
  maven_settings > "$TD/root/.m2/settings.xml"
fi
mkdir -p "$TD/root/" "$TD/etc/pki"
cat >"$TD/root/proxy.env" << EOF
export http_proxy="$tfbuild_custom_image_http_proxy"
export https_proxy="$tfbuild_custom_image_https_proxy"
export no_proxy="$tfbuild_custom_image_no_proxy"
EOF


tar cf /tmp/sandboxcentos.tar -C "$TD" ./
tar cf /tmp/basecentos.tar -C "$TD" ./etc/pki/ ./root/proxy.env
tar cf /tmp/baseubuntu.tar -C "$TD" ./root/proxy.env
rm -rf "$TD"

vanilla centos:7
vanilla centos:7.4.1708
vanilla ubuntu:18.04

customized vanillacentos:7 sandboxcentos:7 \
  /tmp/sandboxcentos.tar \
  "update-ca-trust;$tfbuild_custom_image_sendbox_extra_cmd"

customized vanillacentos:7 basecentos:7 \
  /tmp/basecentos.tar \
  "update-ca-trust; yum -y install epel-release"

customized vanillacentos:7.4.1708 basecentos:7.4.1708 \
  /tmp/basecentos.tar \
  "update-ca-trust;yum makecache; yum -y install epel-release"

customized vanillaubuntu:18.04 baseubuntu:18.04 \
  /tmp/baseubuntu.tar \
  "true"

rm -f /tmp/sandboxcentos.tar /tmp/basecentos.tar /tmp/baseubuntu.tar
