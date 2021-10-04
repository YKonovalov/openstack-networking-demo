#!/bin/sh

  tfbuild_de_repo="${tfbuild_de_repo:-https://github.com/tungstenfabric/tf-dev-env}"
  tfbuild_de_branch="${tfbuild_de_branch:-master}"
  tfbuild_version=R2011

tf_env(){
  tfbuild_de_repo="${tfbuild_de_repo:-https://github.com/tungstenfabric/tf-dev-env}"
  tfbuild_de_branch="${tfbuild_de_branch:-master}"

  for v in tfbuild_{vendor_name,vendor_domain,container_tag,vnc_repo,vnc_branch}; do
   if [ -n "$(eval "echo \$$v")" ]; then
     case "$v" in
     tfbuild_vendor_name)
       echo "export VENDOR_NAME=\"$tfbuild_vendor_name\""
       ;;
     tfbuild_vendor_domain)
       echo "export VENDOR_DOMAIN=\"$tfbuild_vendor_domain\""
       ;;
     tfbuild_container_tag)
       echo "export CONTRAIL_CONTAINER_TAG=\"$tfbuild_container_tag\""
       ;;
     tfbuild_vnc_repo)
       echo "export REPO_INIT_MANIFEST_URL=\"$tfbuild_vnc_repo\""
       ;;
     tfbuild_vnc_branch)
       echo "export REPO_INIT_MANIFEST_BRANCH=\"$tfbuild_vnc_branch\""
       ;;
     esac
   fi
  done
#  echo "export SITE_MIRROR=http://localhost"
  echo "export CONTRAIL_BRANCH=\"$tfbuild_version\""
#  echo "export REPO_URL=\"ssh://git@bitbucket.region.vtb.ru:7999/rock/git-repo.git\""
}
tf_env | tee /root/tfbuild.env

#dnf -y install git python3-virtualenv patch
# alternatives --set python /usr/bin/python3
#apt install git python3-virtualenv patch
#update-alternatives --install /usr/bin/python python /usr/bin/python3 1
#apt install docker.io
if [ ! -d ~/tf-dev-env ]; then
  git clone "$tfbuild_de_repo" -b "$tfbuild_de_branch" ~/tf-dev-env
fi
