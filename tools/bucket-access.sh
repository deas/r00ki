#!/bin/sh

json_output="[]"

buckets=$(radosgw-admin bucket list | jq -r '.[]')

for bucket in $buckets; do
    owner=$(radosgw-admin bucket stats --bucket=$bucket | jq -r '.owner')

    user_info=$(radosgw-admin user info --uid=$owner)
    access_key=$(echo $user_info | jq -r '.keys[0].access_key')
    secret_key=$(echo $user_info | jq -r '.keys[0].secret_key')

    bucket_json=$(jq -n \
        --arg bucket "$bucket" \
        --arg owner "$owner" \
        --arg access_key "$access_key" \
        --arg secret_key "$secret_key" \
        '{bucket: $bucket, owner: $owner, access_key: $access_key, secret_key: $secret_key}')

    json_output=$(echo $json_output | jq --argjson bucket_json "$bucket_json" '. + [$bucket_json]')
done

echo $json_output
