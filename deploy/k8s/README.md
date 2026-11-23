# Post-apply: Angular + Spring REST on private EKS

Run from a trusted Linux operator workstation, **not** from Terraform, a worker or the SSM instance. The demo UI and API deliberately allow anonymous reads and writes from the Internet. Use synthetic records only. Cluster management, ALB and DB still use private networking.

## Handoff

- AWS CLI v2, Session Manager plugin, compatible `kubectl`, Bash, jq, curl, OpenSSL, GNU coreutils and `envsubst`. Use the authorized production AWS profile in both terminals. No tracing, CLI history, debug/proxy body logging, session recording of stdin, or audit policies that record Secret bodies.
- Parent supplies `CLUSTER`, `MANAGER_ID` and a dedicated tunnel kubeconfig. EKS auth and namespace permissions are separate from SSM connectivity. The operator needs `rds:DescribeDBInstances` and `secretsmanager:GetSecretValue` on the master secret (and `kms:Decrypt` if applicable). Neither nodes nor workloads need secret retrieval permission.
- Trusted admins only may read Secrets, write/admit workloads, edit ConfigMaps or exec/debug pods in `petclinic`. Verify encryption at rest for EKS Secrets and back up `petclinic-db-app` through your approved encrypted secrets backup. Namespace `restricted` Pod Security is not access control. No Kubernetes RBAC grants are installed here.
- Nodes in the two app AZs must carry the cluster SG, resolve/reach RDS, pull the pinned PostgreSQL client from Docker Hub and pull both app images from ECR. Allow room for two replicas per app plus rolling surge. Only the internal ALB should be able to reach the NodePorts.
- Images: pass full immutable ECR references (`WEB_IMAGE`, `API_IMAGE`) from the parent's `deploy/publish-release.sh`. The Angular image must serve on 8080 and use same-origin `/petclinic/api`; the REST image must contain the `external-postgres` profile. For a local REST release build with JDK 21: `(cd ../petclinic-eks-source/spring-petclinic-rest && ./mvnw clean package && docker build --platform linux/amd64 -f Dockerfile.runtime -t petclinic-api:release .)`. The parent handles publication.

## 1. Connect and check identity

In terminal A, start the parent's SSM tunnel (skip if already running):

```bash
export AWS_REGION=ap-northeast-2 MANAGER_REGION=ap-northeast-3
# CLUSTER is in Seoul; MANAGER_ID is the Osaka SSM instance (terraform output -json osaka_observe).
export TUNNEL_KUBECONFIG="$(mktemp -d)/kubeconfig"
bash deploy/eks-tunnel.sh
```

Keep it running. In terminal B, run the `export KUBECONFIG=...` printed by the tunnel script (absolute path). It must use `https://127.0.0.1:PORT` or `localhost`, the real EKS hostname as `tls-server-name` and the cluster CA. Never disable TLS verification. Confirm the cluster name/account and inspect the nodes before proceeding:

```bash
aws sts get-caller-identity
kubectl config view --minify -o jsonpath='{.clusters[0].name}{"\n"}'
kubectl get nodes -L topology.kubernetes.io/zone
export DB_HOST=$(terraform -chdir=infra/envs/aws-prod output -raw db_host)
export DB_MASTER_SECRET_ARN=$(terraform -chdir=infra/envs/aws-prod output -raw db_master_secret_arn)
```

These two outputs are identifiers, not secret values. DB name `petclinic`, port `5432`, RDS instance `petclinic-prod-postgres`. Do not put the master password in an environment file, a Terraform data source, kubectl argument, manifest or CI artifact.

## 2. Bootstrap once per database

```bash
# Optional: absolute path if the two checkouts are not siblings.
# export SCHEMA_SQL=/.../spring-petclinic-rest/src/main/resources/db/postgres/schema.sql
bash deploy/k8s/bootstrap.sh
```

The script checks the RDS hostname and secret ARN, installs the regional AWS RDS CA bundle, and creates a random durable app password **only if its Secret is absent**. The reviewed source schema is checksum-checked. The master password travels over verified TLS to a named pipe in a single short-lived Job via `kubectl exec -i` (no TTY); it is never saved in Kubernetes. psql uses `verify-full` and sets the app password with `\password`. DDL, grants and the marker in `petclinic_bootstrap` commit together under a transaction lock. Unmarked non-empty databases are rejected. A retry skips an installed baseline and checks login as the restricted app role; it does not reseed, rotate or reapply DDL. Future schema changes require a separate migration.

On failure, inspect `kubectl -n petclinic describe job petclinic-bootstrap` and pod events (pull, scheduling, readiness). The Job expires after five minutes of execution and is garbage-collected five minutes after termination. Wait for cleanup before retrying. Do not dump Secret YAML, rerun the schema manually, or delete the namespace to retry. If the app Secret is lost, restore its encrypted backup or conduct a coordinated DB-role password reset, Secret replacement and API rollout; a new random value will **not** authenticate against an existing role.

## 3. Deploy by digest and verify

```bash
# Export WEB_IMAGE and API_IMAGE exactly as supplied in the release handoff.
: "${WEB_IMAGE:?required}" "${API_IMAGE:?required}"
bash deploy/k8s/deploy.sh
kubectl -n petclinic get deployment,svc,pods -o wide
```

Expect `2/2` available for `web` and `api`. Both Services use `externalTrafficPolicy: Cluster`: any registered node can forward to a ready pod. Target health paths: web 30080 → 8080 `/`; API 30966 → 9966 `/petclinic/actuator/health/readiness` (includes DB). Liveness does not depend on DB availability.

From an ordinary Internet connection without credentials, check the public domain and read the demo DB without modifying records:

```bash
BASE=$(terraform -chdir=infra/envs/aws-prod output -raw public_url)
curl -fsS "${BASE%/}/" -o /dev/null
curl -fsS "${BASE%/}/petclinic/api/v2/owners?page=0&size=1" | jq -e '(.content | type == "array") and .page == 0 and .size == 1'
```

The legacy `/petclinic/api/owners` can legitimately return 404 when empty. To isolate the API from CloudFront and ALB, use `kubectl -n petclinic port-forward --address 127.0.0.1 svc/api 19966:9966` and repeat the paginated GET locally. Redeploy compatible known-good image digests to roll back app code; do not delete the DB. Close the SSM session and remove the temporary kubeconfig when finished.
