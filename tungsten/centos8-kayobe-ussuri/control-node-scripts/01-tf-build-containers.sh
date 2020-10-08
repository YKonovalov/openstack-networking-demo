#!/bin/sh
. ./config.sh
. ./common/functions.sh

T=`mktemp`
cat > "$T" << \EOF
FROM centos:8 as kernel-centos8
RUN \
  dnf -y update && \
  dnf -y install kernel kernel-core kernel-devel

FROM ubuntu:20.04 as kernel-ubuntu20
ENV DEBIAN_FRONTEND noninteractive
RUN \
  apt-get update && \
  apt-get -y dist-upgrade && \
  apt-get install -y linux-headers-generic linux-image-generic

FROM centos:7
COPY --from=kernel-centos8 / /kernel-centos8/
COPY --from=kernel-ubuntu20 / /kernel-ubuntu20/
RUN ls -l /
RUN du -hs /kernel-centos8/
RUN du -hs /kernel-ubuntu20/
RUN find /kernel-centos8/lib/modules/ -type l -name "build" -exec sh -c 'ln -fs /kernel-centos8`readlink {}` {}' \;
RUN find /kernel-ubuntu20/lib/modules/ -type l -name "build" -exec sh -c 'ln -fs /kernel-ubuntu20`readlink {}` {}' \;
RUN for k in /kernel-centos8/lib/modules/*; do ln -s "$k" /lib/modules/; done
RUN for k in /kernel-ubuntu20/lib/modules/*; do ln -s "$k" /lib/modules/; done

EOF


on-build 'dnf -y install git python3-virtualenv; mkdir ~/bin; ln -s /usr/bin/python3 ~/bin/python'
on-build 'git clone http://github.com/tungstenfabric/tf-dev-env'

on-build 'sed "/^FROM centos:7/d" tf-dev-env/container/Dockerfile.centos /tmp/Dockerfile.centos'
cp-build "$T" tf-dev-env/container/Dockerfile.centos
on-build 'cat /tmp/Dockerfile.centos >> tf-dev-env/container/Dockerfile.centos'

on-build 'tf-dev-env/run.sh'
on-build 'docker exec tf-dev-sandbox ls /lib/modules/ > ~/contrail/tools/packages/kernel_version.info'
on-build 'tf-dev-env/run.sh build'
curl http://build:5000/v2/_catalog|jq -r '.'
