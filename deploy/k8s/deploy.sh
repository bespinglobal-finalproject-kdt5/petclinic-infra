#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
source ./common.sh
: "${WEB_IMAGE:?GHCR web image by digest}" "${API_IMAGE:?GHCR api image by digest}"
prefix='ghcr.io/bespinglobal-finalproject-kdt5/petclinic-'
for kind in web api; do
  var="${kind^^}_IMAGE"; ref=${!var}; digest=${ref##*@}
  [[ $ref == "$prefix$kind@$digest" && $digest =~ ^sha256:[a-f0-9]{64}$ ]] || { echo "Expected organization GHCR petclinic-$kind by digest" >&2; exit 1; }
done
export WEB_IMAGE API_IMAGE
envsubst '$WEB_IMAGE $API_IMAGE $DB_HOST' < apps.yaml.in | k apply -f -
k rollout status deployment/api --timeout=10m
k rollout status deployment/web --timeout=5m
