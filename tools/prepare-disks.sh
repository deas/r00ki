#!/bin/bash
# TODO: Should probably use lvm

set -e

PART_SIZES=${PART_SIZES:-10G 10G}
PART_LABELS=${PART_LABELS:-foo lvm r00ki_bluestore}

partition_device() {
  local device=$1
  local postfix=$2
  local j=1
  {
    echo "label: gpt"
    for s in ${PART_SIZES}; do
      echo ",$s,,"
    done
    echo ",,,"
  } | sfdisk "$device"
  for l in ${PART_LABELS}; do
    sfdisk --part-label "$device" "$j" "${l}-${postfix}"
    j=$((j + 1))
  done
  # TODO: No partprobe on openshift
  # partprobe "$device"
}

i=1
lsblk -dn -o NAME,SIZE | grep -v ' 0B$' | sort | while read -r device size; do
  if [ -z "$(lsblk /dev/$device -n -o NAME | tail -n +2)" ]; then
    partition_device "/dev/$device" "$i"
    i=$((i + 1))
    # echo "$device ($size)"
  fi
done
