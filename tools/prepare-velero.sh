#!/bin/bash

set -e

NS="${NS:=velero}"
TOOLS_DIR="${TOOLS_DIR:=.}"
# ENV="${ENV:=local}"

# Need to make sure the secret/config map exists before we setup s3 environment
kubectl -n rook-ceph wait --timeout=180s --for=jsonpath='{.status.phase}'=Bound obc/my-store

source ${TOOLS_DIR}/s3-bucket-env.sh

cat <<EOF >apps/velero/values-dynamic.yaml
configuration:
  features: EnableCSI
  defaultSnapshotMoveData: true

  backupStorageLocation:
    - name: default
      provider: aws
      accessMode: ReadWrite
      config:
        region: dummy
        s3ForcePathStyle: "true"
        s3Url: ${AWS_ENDPOINT_URL}
      bucket: ${BUCKET_NAME}
      credential:
        name: cloud-credentials
        key: content

  volumeSnapshotLocation:
    - name: default
      provider: csi
EOF

secret_content=$(
  cat <<EOF | base64 -w 0
[default]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
EOF
)

kubectl create ns ${NS} --dry-run=client -o yaml | kubectl apply -f -

cat <<EOF | kubectl apply -f -
apiVersion: v1
data:
  content: ${secret_content}
kind: Secret
metadata:
  name: cloud-credentials
  namespace: ${NS}
EOF
