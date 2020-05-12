#!/bin/sh

vmDel() {
nova list|sed -n "s/^| \([0-9a-f-]\+\).*/\1/p"|while read id; do nova delete $id; done
}

netDel() {
neutron net-list|sed -n "s/^| \([0-9a-f-]\+\).*/\1/p"|while read id; do neutron net-delete $id; done
}

vmDel
netDel
