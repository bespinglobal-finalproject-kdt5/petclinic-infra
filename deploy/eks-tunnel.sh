#!/usr/bin/env bash
# Run on the operator workstation after apply. This does not open the EKS public endpoint.
set -euo pipefail
umask 077
: "${CLUSTER:?set CLUSTER to the EKS cluster name}" "${MANAGER_ID:?set MANAGER_ID to the SSM-managed instance ID}"
export AWS_REGION=${AWS_REGION:-ap-northeast-2}
: "${TUNNEL_KUBECONFIG:?set TUNNEL_KUBECONFIG to a new private temporary path}"
[[ ! -e "$TUNNEL_KUBECONFIG" ]] || { echo 'Refusing to overwrite an existing kubeconfig' >&2; exit 1; }
port=${LOCAL_PORT:-18443}
[[ $port =~ ^[0-9]+$ ]] && (( port > 1023 && port < 65536 )) || exit 2
endpoint=$(aws eks describe-cluster --name "$CLUSTER" --query cluster.endpoint --output text)
host=${endpoint#https://}
[[ $host != "$endpoint" && $host != */* ]] || exit 1
# Use the existing bootstrap operator's IAM identity; port forwarding grants no K8s permissions.
aws eks update-kubeconfig --name "$CLUSTER" --alias petclinic --kubeconfig "$TUNNEL_KUBECONFIG" >/dev/null
key=$(kubectl --kubeconfig="$TUNNEL_KUBECONFIG" config view --minify -o jsonpath='{.clusters[0].name}')
kubectl --kubeconfig="$TUNNEL_KUBECONFIG" config set-cluster "$key" --server="https://127.0.0.1:$port" --tls-server-name="$host" >/dev/null
printf 'In another terminal use: export KUBECONFIG=%q\n' "$TUNNEL_KUBECONFIG"
aws ssm start-session --region "${MANAGER_REGION:-ap-northeast-3}" --target "$MANAGER_ID" --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "$(jq -cn --arg host "$host" --arg port "$port" '{host:[$host],portNumber:["443"],localPortNumber:[$port]}')"
