#!/usr/bin/env bash
set +x
set -euo pipefail
cd "$(dirname "$0")"
source ./common.sh
: "${DB_MASTER_SECRET_ARN:?Set from terraform output -raw db_master_secret_arn}"
export AWS_PAGER='' AWS_CLI_AUTO_PROMPT=off
[[ $(aws configure get cli_history || :) != enabled ]] || { echo 'Disable AWS CLI history before bootstrap' >&2; exit 1; }
# Match the ARN and endpoint to this instance in the active AWS account before streaming anything.
aws rds describe-db-instances --region ap-northeast-2 --db-instance-identifier petclinic-prod-postgres --output json | jq -e --arg host "$DB_HOST" --arg arn "$DB_MASTER_SECRET_ARN" '.DBInstances[0] | .Endpoint.Address == $host and .MasterUserSecret.SecretArn == $arn and .MasterUserSecret.SecretStatus == "active" and .MasterUsername == "petclinic_admin"' >/dev/null
schema=${SCHEMA_SQL:-../../../petclinic-eks-source/spring-petclinic-rest/src/main/resources/db/postgres/schema.sql}
[[ $(sha256sum "$schema" | cut -d' ' -f1) == cec826204ce5e8317305bc8dd07a932a3abd964adfeccc4ad73eec38daaade07 ]] || { echo 'Unexpected baseline schema; use a reviewed migration instead' >&2; exit 1; }
k create namespace petclinic --dry-run=client -o yaml | k apply -f -
k label namespace petclinic pod-security.kubernetes.io/enforce=restricted --overwrite
ca=$(mktemp); trap 'rm -f "$ca"' EXIT
curl --fail --silent --show-error --proto '=https' https://truststore.pki.rds.amazonaws.com/ap-northeast-2/ap-northeast-2-bundle.pem -o "$ca"
openssl x509 -in "$ca" -noout
k create configmap rds-ca --from-file="ca.pem=$ca" --dry-run=client -o yaml | k apply -f -
k create configmap petclinic-bootstrap-v1 --from-file=bootstrap-entry.sh --from-file=bootstrap.sql --from-file="schema.sql=$schema" --dry-run=client -o yaml | k apply -f -
existing=$(k get secret petclinic-db-app --ignore-not-found -o name)
if [[ -z $existing ]]; then
  openssl rand -hex 32 | tr -d '\n' | k create secret generic petclinic-db-app --from-file=password=/dev/stdin
fi
# Fixed name serializes operators; never attach to an existing Job on conflict.
uid=$(envsubst '$DB_HOST' < bootstrap.yaml.in | k create -f - -o jsonpath='{.metadata.uid}')
selector="batch.kubernetes.io/controller-uid=$uid"
for _ in {1..60}; do
  pod=$(k get pods -l "$selector" -o name)
  [[ -z $pod ]] || break
  sleep 1
done
: "${pod:?No bootstrap pod created; inspect job events}"
k wait --for=condition=Ready "$pod" --timeout=150s
# No TTY, argv, local secret file, echoed secret or Kubernetes master Secret.
aws secretsmanager get-secret-value --region ap-northeast-2 --secret-id "$DB_MASTER_SECRET_ARN" --version-stage AWSCURRENT --query SecretString --output text | jq -er 'select(.username == "petclinic_admin") | .password | strings | select(length > 0)' | k exec -i "$pod" -c bootstrap -- sh -c 'cat > /tmp/master-in'
k wait --for=condition=complete job/petclinic-bootstrap --timeout=110s
k delete job petclinic-bootstrap --wait=true
