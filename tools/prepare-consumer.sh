#/bin/sh
# Generate config.ini on stdout
set -e
# OPERATOR_NS=rook-ceph
ROOK_CLUSTER_NS=rook-ceph
STORE=my-store
FS=myfs
POOL=replicapool
INI_FILE=config.ini
MANIFEST_DYNAMIC=apps/rook-ceph-cluster-external/files/manifest-dynamic.yaml
TOOLS_DIR="$(cd "$(dirname "$0")" && pwd)"
#CONTEXT="todo"
#NODENAME="todo"
# TODO
# CONSUMER_MODE=$1 # intern or extern
ENV_TYPE=$1
# TODO: Beware of the k8s contexts!

# Alternatively, we could do the waiting in a helm job
kubectl -n ${ROOK_CLUSTER_NS} wait --timeout=240s --for=jsonpath='{.status.phase}'=Ready cephblockpool/${POOL}
kubectl -n ${ROOK_CLUSTER_NS} wait --timeout=240s --for=jsonpath='{.status.phase}'=Ready cephobjectstore/${STORE}
# Have to wait for the external address of the endpoint - which does not appear to be covered by the store being ready
kubectl -n ${ROOK_CLUSTER_NS} wait --timeout=240s --for=jsonpath='{.subsets[0].addresses[0].ip}' ep/rook-ceph-rgw-my-store
kubectl -n ${ROOK_CLUSTER_NS} wait --timeout=240s --for=jsonpath='{.status.phase}'=Ready cephfilesystem/${FS}
# kubectl -n ${ROOK_CLUSTER_NS} wait --timeout=240s --for=jsonpath='{.subsets[0].addresses[0].nodeName}'=${NODENAME} ep/rook-ceph-rgw-${STORE}

# echo ${ENV_TYPE}

if [ "${ENV_TYPE}" != "service" ]; then
  if ! kubectl rook-ceph radosgw-admin user info --uid rgw-admin-ops-user >/dev/null; then
    kubectl rook-ceph radosgw-admin user create --uid rgw-admin-ops-user --display-name "Rook RGW Admin Ops user" --caps "buckets=*;users=*;usage=read;metadata=read;zone=read" --rgw-realm "" --rgw-zonegroup "" --rgw-zone ""
    # kubectl rook-ceph radosgw-admin caps add --uid rgw-admin-ops-user --caps info=read --rgw-realm "" --rgw-zonegroup --rgw-zone ""
    kubectl rook-ceph radosgw-admin user info --uid=rgw-admin-ops-user | jq '.keys[0] | {
    apiVersion: "v1",
    kind: "Secret",
    type: "kubernetes.io/rook",
    metadata: {name: "rgw-admin-ops-user", namespace: "rook-ceph"},
    data: {accessKey: .access_key | @base64, secretKey: .secret_key | @base64}
  }' | kubectl apply -f -
  fi
  echo "export RGW_ENDPOINT=rook-ceph-rgw-${STORE}.${ROOK_CLUSTER_NS}.svc.cluster.local:8080" >${INI_FILE}
  # echo -n "export RGW_ENDPOINT="
  #kubectl -n rook-ceph get endpoints -l app=rook-ceph-rgw \
  #  -o jsonpath="{.items[0].subsets[0].addresses[0].ip}:{.items[0].subsets[0].ports[?(@.name=='http')].port}"
else
  # TODO: unable to connect to endpoint: 192.168.122.74:9926, failed error: HTTPSConnectionPool(host='192.168.122.74', port=9926): Read timed out
  # exporter_ep=$(kubectl -n ${ROOK_CLUSTER_NS} get endpoints -l app=rook-ceph-exporter -o jsonpath="{.items[0].subsets[0].addresses[0].ip}")
  # exporter_ep_port=$(kubectl -n ${ROOK_CLUSTER_NS} get endpoints -l app=rook-ceph-exporter -o jsonpath="{.items[0].subsets[0].ports[?(@.name=='ceph-exporter-http-metrics')].port}")
  rgw_ep=$(kubectl -n ${ROOK_CLUSTER_NS} get endpoints -l app=rook-ceph-rgw -o jsonpath="{.items[0].subsets[0].addresses[0].ip}:{.items[0].subsets[0].ports[?(@.name=='http')].port}")
  # https://rook.io/docs/rook/latest/CRDs/Cluster/external-cluster/provider-export/
  create_script="${TOOLS_DIR}/./create-external-cluster-resources.py"
  cat "${create_script}" | kubectl exec -i -n ${ROOK_CLUSTER_NS} deploy/rook-ceph-tools -- \
    python3 - \
    --rbd-data-pool-name ${POOL} \
    --rgw-endpoint ${rgw_ep} \
    --namespace ${ROOK_CLUSTER_NS} \
    --format bash >${INI_FILE}

  echo "externalRgwEndpoint: $(echo $rgw_ep | cut -d : -f 1)" >apps/rook-ceph-cluster-external/envs/mini-consumer/values.yaml

# If encryption or compression on the wire is needed, specify the
# --v2-port-enable
#  --monitoring-endpoint ${exporter_ep} \
#  --monitoring-endpoint-port ${exporter_ep_port} \

fi

if [ "${ENV_TYPE}" != "aio" ]; then
  "${TOOLS_DIR}/import-external-cluster-manifests.sh" >${MANIFEST_DYNAMIC}
fi
