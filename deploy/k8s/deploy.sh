#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
# Set the trusted namespace independently of the supplied images (registry DNS/owner).
: "${APP_IMAGE_NAMESPACE:?Set the approved registry/owner}" "${WEB_IMAGE:?Web image by digest}" "${API_IMAGE:?API image by digest}"
[[ $APP_IMAGE_NAMESPACE =~ ^[a-z0-9-]+(\.[a-z0-9-]+)+/[a-z0-9]+([._-][a-z0-9]+)*$ ]] || { echo 'Expected registry/owner' >&2; exit 1; }
for image in "$WEB_IMAGE" "$API_IMAGE"; do
  ref=${image#"$APP_IMAGE_NAMESPACE/"}
  [[ $ref != "$image" && $ref =~ ^[a-z0-9]+([._-][a-z0-9]+)*@sha256:[a-f0-9]{64}$ ]] || { echo 'Expected an approved repository pinned by sha256 digest' >&2; exit 1; }
done
source ./common.sh
export WEB_IMAGE API_IMAGE
envsubst '$WEB_IMAGE $API_IMAGE $DB_HOST' < apps.yaml.in | k apply -f -
k rollout status deployment/api --timeout=10m
k rollout status deployment/web --timeout=5m
