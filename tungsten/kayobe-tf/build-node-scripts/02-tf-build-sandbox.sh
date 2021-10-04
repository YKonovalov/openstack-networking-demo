#!/bin/sh

. /root/tfbuild.env

docker rm centos:7
docker tag sandboxcentos:7 centos:7

export CONTRAIL_BRANCH="R2011"

(cd; ~/tf-dev-env/run.sh)

echo "finnished: $0 with $?"
