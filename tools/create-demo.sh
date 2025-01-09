#!/bin/sh
#SCRIPT_DIR="$(dirname "$0")"
# SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# echo $SCRIPT_DIR

targets="apply-r00ki-aio test-csi-io test-csi-snapshot test-velero"

for target in $targets; do
  echo "$target" | figlet | lolcat
  sleep 2
  make "$target"
done
