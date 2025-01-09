#!/bin/sh
# https://rook.io/docs/rook/latest/Getting-Started/ceph-teardown/
set -xe

wipe_device() {
  local device=$1
  # TODO: minikube does not have sgdisk
  # sgdisk --zap-all $DISK

  # Wipe a large portion of the beginning of the disk to remove more LVM metadata that may be present
  dd if=/dev/zero of="$device" bs=1M count=100 oflag=direct,dsync

  # SSDs may be better cleaned with blkdiscard instead of dd
  # blkdiscard $DISK

  # TODO: Openshift does not have partprobe
  # Inform the OS of partition table changes
  # partprobe $DISK
}

blkid -t TYPE=ceph_bluestore | cut -d : -f 1 | while read dev; do
  wipe_device "$dev"
done
