#!/bin/sh

set -e

CERT=$1

csplit -s -z - '/^---$/' '{*}'

for file in xx*; do
  kubeseal -n "${NAMESPACE}" --cert "${CERT}" --format yaml <"$file"
  echo "---"
  rm "$file"
done
