#!/usr/bin/env bash
# Post-approval only. Publish existing local linux/amd64 images to the newly created repositories.
set -euo pipefail
umask 077
: "${WEB_LOCAL:?set WEB_LOCAL to a tested local Angular image}" "${API_LOCAL:?set API_LOCAL to a tested local REST image}"
region=ap-northeast-2
account=$(aws sts get-caller-identity --query Account --output text)
: "${EXPECTED_AWS_ACCOUNT:?confirm the production account ID}"; [[ $account == "$EXPECTED_AWS_ACCOUNT" ]] || exit 2
registry="$account.dkr.ecr.$region.amazonaws.com"
docker_cfg=$(mktemp -d); trap 'rm -rf -- "$docker_cfg"' EXIT
# Read immutable IDs before any push. ECR tags are content-based, not latest.
refs=("$WEB_LOCAL" "$API_LOCAL"); keys=(web api); ids=(); tags=()
for i in 0 1; do
  ref=${refs[i]}; arch=$(docker image inspect "$ref" --format '{{.Os}}/{{.Architecture}}'); [[ $arch == linux/amd64 ]] || exit 2
  id=$(docker image inspect "$ref" --format '{{.Id}}'); ids+=("$id"); tags+=("img-${id#sha256:}")
  name=petclinic-prod/${keys[i]}; url=$(aws ecr describe-repositories --region "$region" --repository-names "$name" --query 'repositories[0].repositoryUri' --output text); [[ $url == "$registry/$name" ]] || exit 2
done
aws ecr get-login-password --region "$region" | docker --config "$docker_cfg" login --username AWS --password-stdin "$registry" >&2
for i in 0 1; do
  name=petclinic-prod/${keys[i]}; tag=${tags[i]}; dst="$registry/$name:$tag"
  if ! digest=$(aws ecr describe-images --region "$region" --repository-name "$name" --image-ids "imageTag=$tag" --query 'imageDetails[0].imageDigest' --output text 2>"$docker_cfg/error"); then
    grep -q ImageNotFoundException "$docker_cfg/error" || { cat "$docker_cfg/error" >&2; exit 1; }
    docker image tag "${ids[i]}" "$dst"; docker --config "$docker_cfg" push "$dst" >&2
    digest=$(aws ecr describe-images --region "$region" --repository-name "$name" --image-ids "imageTag=$tag" --query 'imageDetails[0].imageDigest' --output text)
  fi
  [[ $digest =~ ^sha256:[a-f0-9]{64}$ ]] || exit 1
  printf '%s=%s/%s@%s\n' "${keys[i]^^}_IMAGE" "$registry" "$name" "$digest"
done
