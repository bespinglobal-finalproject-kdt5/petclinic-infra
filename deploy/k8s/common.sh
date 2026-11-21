# Sourced by bootstrap.sh and deploy.sh; never select the operator's default cluster.
: "${KUBECONFIG:?Set the dedicated parent-provided tunnel kubeconfig}" "${DB_HOST:?Set from terraform output -raw db_host}"
[[ -f $KUBECONFIG && $KUBECONFIG != *:* ]] || { echo 'Expected a single kubeconfig file' >&2; exit 1; }
k() { kubectl --kubeconfig "$KUBECONFIG" -n petclinic "$@"; }
k config view --minify -o json | jq -e '.clusters[0].cluster | (.server | test("^https://(127\\.0\\.0\\.1|localhost):[0-9]+$")) and (."tls-server-name" | type == "string" and length > 0) and (."insecure-skip-tls-verify" != true)' >/dev/null || { echo 'Expected the verified private API tunnel kubeconfig' >&2; exit 1; }
[[ $DB_HOST =~ ^petclinic-prod-postgres\.[a-z0-9]+\.ap-northeast-2\.rds\.amazonaws\.com$ ]] || { echo 'Expected the Seoul Petclinic RDS instance hostname' >&2; exit 1; }
export DB_HOST
