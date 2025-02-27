#!/bin/bash

block_devices=$(lsblk -dpno NAME | grep -E '^/dev/sd|^/dev/nvme|^/dev/vd')

for device in $block_devices; do
  dev_name=$(basename $device)
  # dev_size=$(lsblk -dnbo SIZE $device)Ki
  dev_size=$(lsblk -dnbo SIZE $device | awk '{print int($1/1024/1024/1024)"Gi"}')

  cat <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-$dev_name
spec:
  capacity:
    storage: ${dev_size}
  volumeMode: Block
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: manual
  local:
    path: $device
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
                - $(hostname)
---
EOF
done
