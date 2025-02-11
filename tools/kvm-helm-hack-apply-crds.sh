#!/bin/bash
# TODO: This is a terrible helm on minikube/kvm workaround!

set -e

target_dir="./target"
olm_version=0.30.0
kube_prometheus_stack_version=67.4.0
grafa_operator_version=v5.16.0
velero_version=8.3.0
kubectl="kubectl apply --server-side=true"

[ -d "${target_dir}" ] || mkdir -p "${target_dir}"

if [ ! -e "${target_dir}/olm-crds.yaml" ]; then
  helm template oci://ghcr.io/cloudtooling/helm-charts/olm --version ${olm_version} --include-crds |
    yq 'select(.kind == "CustomResourceDefinition")' >"${target_dir}/olm-crds.yaml"
fi

${kubectl} -f "${target_dir}/olm-crds.yaml"

if [ ! -e "${target_dir}/kube-prometheus-stack-crds.yaml" ]; then
  helm --repo https://prometheus-community.github.io/helm-charts template kube-prometheus-stack --version ${kube_prometheus_stack_version} --include-crds |
    yq 'select(.kind == "CustomResourceDefinition")' >"${target_dir}/kube-prometheus-stack-crds.yaml"
fi

${kubectl} -f "${target_dir}/kube-prometheus-stack-crds.yaml"

if [ ! -e "${target_dir}/velero-grafana.yaml" ]; then
  helm template oci://ghcr.io/grafana/helm-charts/grafana-operator --version ${grafa_operator_version} --include-crds |
    yq 'select(.kind == "CustomResourceDefinition")' >"${target_dir}/grafana-crds.yaml"
fi

${kubectl} -f "${target_dir}/grafana-crds.yaml"

for arg in "$@"; do
  if [ "${arg}" = "velero" ]; then
    if [ ! -e "${target_dir}/velero-crds.yaml" ]; then
      helm --repo https://vmware-tanzu.github.io/helm-charts template velero --version ${velero_version} --include-crds |
        yq 'select(.kind == "CustomResourceDefinition")' >"${target_dir}/velero-crds.yaml"
    fi
    ${kubectl} -f "${target_dir}/velero-crds.yaml"
  fi
done
