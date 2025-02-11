#!/bin/sh

NAMESPACE=${NAMESPACE:="rook-ceph"}
RESOURCES=${RESOURCES:="cephblockpool,cephfilesystemsubvolumegroups,cephblockpoolradosnamespaces"}
# cephfilesystems,cephblockpools,cephobjectstore,cephfilesystemsubvolumegroups,obc
# pvc

kubectl -n "${NAMESPACE}" get ${RESOURCES} --no-headers -o name |
  xargs -I {} echo kubectl annotate {} rook.io/force-deletion="true"

#kubectl -n "${NAMESPACE}" get cephfilesystems,cephblockpools,cephobjectstore,cephfilesystemsubvolumegroups,obc --no-headers -o name |
#  xargs kubectl -n "${NAMESPACE}" delete
