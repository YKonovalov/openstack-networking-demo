#!/bin/sh

. /root/tfbuild.env

docker rm centos:7
docker tag basecentos:7 centos:7
docker rm centos:7.4.1708
docker tag basecentos:7.4.1708 centos:7.4.1708
docker rm ubuntu:18.04
docker tag baseubuntu:18.04 ubuntu:18.04

docker exec tf-dev-sandbox ls /lib/modules/ | grep ^4|tee ~/contrail/tools/packages/kernel_version*.info
export MULTI_KERNEL_BUILD=true

(cd; ~/tf-dev-env/run.sh build)

curl http://localhost:5001/v2/_catalog|jq -r '.'

echo "finnished: $0 with $?"
