#!/bin/bash

# ghcr-proxy ghcr.io quay-proxy quay.io docker-proxy docker.io k8s-proxy registry.k8s.io
containers=("$@")

# level=warning msg="failed to load plugin io.containerd.grpc.v1.cri" error="invalid plugin config: `mirrors` cannot be set when `config_path` is provided"
for ((i = 0; i < ${#containers[@]}; i += 2)); do
  container_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${containers[i]}")
  echo "[plugins.\"io.containerd.grpc.v1.cri\".registry.mirrors.\"${containers[i + 1]}\"] # proxy-patch"
  echo "endpoint = [\"http://${container_ip}:5000\"] # proxy-patch"
done
