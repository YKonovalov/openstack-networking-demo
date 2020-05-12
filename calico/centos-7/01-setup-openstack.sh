#!/bin/sh

yum update -y
yum install -y centos-release-openstack-queens
yum update -y
yum install -y openstack-packstack
packstack --allinone
sed -i 's/^\(CONFIG_COMPUTE_HOSTS\)=.*/\1=172.31.0.35,172.31.0.32,172.31.0.45/' packstack-answers-20200507-141550.txt
packstack --answer-file=packstack-answers-20200507-141550.txt
