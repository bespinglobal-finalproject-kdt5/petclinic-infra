#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
source ./common.sh
: "${WEB_IMAGE:?Full ECR web image by digest}" "${API_IMAGE:?Full ECR api image by digest}"
for image in "$WEB_IMAGE" "$API_IMAGE"; do
  [[ $image =~ ^[0-9]{12}\.dkr\.ecr\.ap-northeast-2\.amazonaws\.com/[a-z0-9][a-z0-9._/-]*@sha256:[a-f0-9]{64}$ ]] || { echo 'Expected full Seoul ECR image by digest' >&2; exit 1; }
done
export WEB_IMAGE API_IMAGE
envsubst '$WEB_IMAGE $API_IMAGE $DB_HOST' < apps.yaml.in | k apply -f -
k rollout status deployment/api --timeout=10m
k rollout status deployment/web --timeout=5m
