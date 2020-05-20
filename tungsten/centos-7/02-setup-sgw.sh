#!/bin/sh
alias sgw='pdsh -w sgw[1-3]'
alias sgwcp='pdcp -w sgw[1-3]'

git clone git@github.com:YKonovalov/sgw.git
install -m 700 sgw /usr/local/bin/
sgwcp /usr/local/bin/sgw /usr/local/bin/sgw.
sgw dnf -y install jq tcpdump kernel-modules

sgw 'sgw --create'
