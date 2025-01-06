#!/bin/bash
# https://github.com/containerd/containerd/blob/main/docs/cri/registry.md
# https://stackoverflow.com/questions/74595635/how-to-configure-containerd-to-use-a-registry-mirror
# https://github.com/containerd/containerd/discussions/10909
set -e

CONFIG_FILE=${CONFIG_FILE:-/etc/containerd/config.toml} # /etc/containerd/config.toml}

cp "${CONFIG_FILE}" "${CONFIG_FILE}.orig"

{
  grep -v proxy-patch "${CONFIG_FILE}.orig" | grep -v "config_path\s*="
  cat
} >"${CONFIG_FILE}"
