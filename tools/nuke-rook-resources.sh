#!/bin/sh

NAMESPACE=${NAMESPACE:="rook-ceph"}

# Delete the CephCluster CRD
kubectl -n "${NAMESPACE}" patch cephcluster rook-ceph --type merge -p '{"spec":{"cleanupPolicy":{"confirmation":"yes-really-destroy-data"}}}' || true
kubectl -n "${NAMESPACE}" delete cephcluster rook-ceph || true

# TODO Ensure Ceph is gone

# When a Cluster CRD is created, a finalizer is added automatically by the Rook operator.
# The finalizer will allow the operator to ensure that before the cluster CRD is deleted, all
# block and file mounts will be cleaned up. Without proper cleanup, pods consuming the
# storage will be hung indefinitely until a system reboot.

# The operator is responsible for removing the finalizer after the mounts have been cleaned
# up. If for some reason the operator is not able to remove the finalizer (i.e., the operator
# is not running anymore), delete the finalizer manually with the following command:

for crd in $(kubectl get crd -n "${NAMESPACE}" | awk '/ceph.rook.io/ {print $1}'); do
  kubectl get -n "${NAMESPACE}" "$crd" -o name |
    xargs -I {} kubectl patch -n "${NAMESPACE}" {} --type merge -p '{"metadata":{"finalizers": []}}'
done

# If the namespace is still stuck in Terminating state, check which resources are holding up the
# deletion and remove their finalizers as well:

# kubectl api-resources --verbs=list --namespaced -o name \
#   | xargs -n 1 kubectl get --show-kind --ignore-not-found -n "${NAMESPACE}"

# Rook adds a finalizer ceph.rook.io/disaster-protection to resources critical to the Ceph cluster
# so that the resources will not be accidentally deleted.

# The operator is responsible for removing the finalizers when a CephCluster is deleted. If the
# operator is not able to remove the finalizers (i.e., the operator is not running anymore),
# remove the finalizers manually:

# kubectl -n "${NAMESPACE}" patch configmap rook-ceph-mon-endpoints --type merge -p '{"metadata":{"finalizers": []}}'
# kubectl -n "${NAMESPACE}" patch secrets rook-ceph-mon --type merge -p '{"metadata":{"finalizers": []}}'

# Force Delete Resources
# This cleanup is supported only for the following custom resources:
# kubectl -n "${NAMESPACE}" annotate cephfilesystemsubvolumegroups.ceph.rook.io my-subvolumegroup rook.io/force-deletion="true"
# kubectl -n "${NAMESPACE}" delete cephfilesystemsubvolumegroups.ceph.rook.io my-subvolumegroup
