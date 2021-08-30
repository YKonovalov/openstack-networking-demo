#!/bin/sh
D=`dirname $0`

bash "$D/00-cluster-infra.sh" 2>&1 | tee 00-cluster-infra.log
tmux -vv set-option -g history-limit 15000 \; new-session -d -s setup
tmux send -t setup "sh $D/cluster-do-setup.sh" ENTER
