#!/usr/bin/env bash
# Publish the tested local images; docker must already be authenticated to ghcr.io.
# Use a private DOCKER_CONFIG or OS credential helper; never pass tokens as arguments.
set -euo pipefail
umask 077
: "${WEB_LOCAL:?tested local Angular image}" "${API_LOCAL:?tested local REST image}"
org=bespinglobal-finalproject-kdt5
refs=("$WEB_LOCAL" "$API_LOCAL"); apps=(web api); ids=(); output=()
log=$(mktemp); trap 'rm -f "$log"' EXIT
for ref in "${refs[@]}"; do
  [[ $(docker image inspect "$ref" --format '{{.Os}}/{{.Architecture}}') == linux/amd64 ]] || { echo 'Expected linux/amd64 image' >&2; exit 2; }
  ids+=("$(docker image inspect "$ref" --format '{{.Id}}')")
done
for i in 0 1; do
  image="ghcr.io/$org/petclinic-${apps[i]}"; tag="img-${ids[i]#sha256:}"
  docker tag "${ids[i]}" "$image:$tag"
  docker push "$image:$tag" >"$log" || { echo "Push failed for $image (GHCR write:packages and organization access required)" >&2; exit 1; }
  digest=$(sed -nE 's/^.*digest: (sha256:[0-9a-f]{64}) size: [0-9]+.*$/\1/p' "$log" | tail -1)
  [[ $digest =~ ^sha256:[a-f0-9]{64}$ ]] || { echo 'Cannot determine pushed manifest digest' >&2; exit 1; }
  docker manifest inspect "$image@$digest" >/dev/null
  output+=("${apps[i]^^}_IMAGE=$image@$digest")
done
printf '%s\n' "${output[@]}"
