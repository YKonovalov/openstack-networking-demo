#!/bin/sh

maven_settings(){
  cat << EOF
<?xml version="1.0" encoding="UTF-8"?>
<settings xmlns="http://maven.apache.org/SETTINGS/1.1.0"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.1.0 http://maven.apache.org/xsd/settings-1.1.0.xsd">
  <servers>
    <server>
      <id>central</id>
      <username>$tfbuild_custom_image_maven_user</username>
      <password>$tfbuild_custom_image_maven_pass</password>
    </server>
  </servers>
  <mirrors>
    <mirror>
      <id>central</id>
      <name>central</name>
      <url>$tfbuild_custom_image_maven_proxy</url>
      <mirrorOf>*</mirrorOf>
    </mirror>
  </mirrors>
</settings>
EOF
}

ssh_keyscan(){
  ssh-keyscan $tfbuild_custom_image_ssh_keyscan_args 2>/dev/null
}

vanilla(){
  local image="$1"
  if [ -n "$(docker image ls -q vanilla$image)" ]; then
    return
  fi
  [ -n "$(docker image ls -q $image)" ] && docker image rm $image
  docker pull $image
  docker tag $image vanilla$image
}

customized(){
  local simage="$1"
  local timage="$2"
  local tarball="$3"
  local cmd="$4"
  if [ -n "$(docker image ls -q $timage)" ]; then
    return
  fi
  local BD="$(mktemp -d)"
  cp $tarball "$BD/add.tar"
  cat >$BD/Dockerfile << EOF
FROM $simage
ADD add.tar /
RUN $cmd
EOF
  docker build --network=host -t $timage "$BD/"
  rm -rf "$BD"
}
