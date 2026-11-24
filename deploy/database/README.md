# EKS REST API와 PostgreSQL 연결

서울 서비스 VPC에서 REST Pod는 RDS Proxy의 DNS 이름으로 TCP 5432를 사용한다. Proxy가 DB 서브넷의 PostgreSQL에 접속한다. 현재 노드 그룹은 기본 EKS 클러스터 보안 그룹을 사용한다. 따라서 Proxy 규칙은 이 보안 그룹을 공유하는 워크로드에 적용된다. Pod 전용 보안 그룹을 도입하면 소스 보안 그룹도 조정한다.

## DB 역할과 스키마 준비

운영 Terraform 적용 후, S3 backend가 초기화된 저장소 루트에서 실행한다. 운영자에게 SSM 포트 포워딩, RDS 관리자 및 앱 Secret 조회 권한이 필요하다. 로컬에 AWS CLI, Session Manager 플러그인, jq, psql 16 및 팀이 배포할 앱 소스가 있어야 한다.

```bash
export AWS_REGION=ap-northeast-2
db=$(terraform -chdir=infra/envs/aws-prod output -json database_connection)
db_host=$(jq -r .instance_address <<<"$db")
ssm_target=$(jq -r .bootstrap_instance_id <<<"$db")
aws ssm start-session --target "$ssm_target" \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "$(jq -nc --arg host "$db_host" '{host:[$host],portNumber:["5432"],localPortNumber:["15432"]}')"
```

터널을 열어 둔다. 두 번째 터미널에서 `app_repo`를 배포할 앱 커밋의 체크아웃 경로로 설정한다. 관리자 암호는 RDS의 관리형 마스터 Secret에서, 앱 암호는 `database_connection.app_secret_arn`에서 권한 있는 운영자가 확인한다. 첫 암호 프롬프트에 마스터 암호를, 이어지는 두 프롬프트에 동일한 **앱 Secret의 암호**를 입력한다.

```bash
export AWS_REGION=ap-northeast-2
db=$(terraform -chdir=infra/envs/aws-prod output -json database_connection)
app_repo=../petclinic-eks-app
schema_file=$(realpath "$app_repo/petclinic-rest/src/main/resources/db/postgres/schema.sql")
mkdir -p "$HOME/.postgresql"
curl -fsSL https://truststore.pki.rds.amazonaws.com/ap-northeast-2/ap-northeast-2-bundle.pem \
  -o "$HOME/.postgresql/petclinic-seoul-rds.pem"
PGHOST="$(jq -r .instance_address <<<"$db")" PGHOSTADDR=127.0.0.1 PGPORT=15432 \
  PGSSLMODE=verify-full PGSSLROOTCERT="$HOME/.postgresql/petclinic-seoul-rds.pem" \
  psql -X -W -U petclinic -d petclinic -v schema_file="$schema_file" -f deploy/database/bootstrap.sql
```

스크립트는 빈 `public` 스키마에 앱의 테이블을 생성한다. 기존 스키마에서는 앱 테이블·시퀀스에 실행 권한을 부여하고 앱 계정 암호를 맞춘다. 스키마가 앱 버전과 다르면 해당 버전의 마이그레이션을 먼저 수행한다. 샘플 데이터는 운영 초기화에서 제외한다.

## WAS 설정과 확인

프라이빗 EKS API에 연결할 수 있는 호스트에서 운영 클러스터의 kubectl 컨텍스트를 선택한다. 아래 예시는 팀의 `petclinic` 네임스페이스, `Deployment/api`, 컨테이너 `api`를 사용한다. 앱 이미지의 JVM 신뢰 저장소에 RDS Proxy의 ACM 인증서를 검증할 Amazon 루트 CA가 있어야 한다.

```bash
set -euo pipefail
export AWS_REGION=ap-northeast-2
db=$(terraform -chdir=infra/envs/aws-prod output -json database_connection)
proxy=$(jq -er .proxy_endpoint <<<"$db")
app_secret=$(jq -er .app_secret_arn <<<"$db")
aws secretsmanager get-secret-value --secret-id "$app_secret" --query SecretString --output text |
  jq -ce --arg url "jdbc:postgresql://$proxy:5432/petclinic?sslmode=verify-full&sslfactory=org.postgresql.ssl.DefaultJavaSSLFactory" '
    select(.username == "petclinic_app" and (.password | type == "string" and length > 0)) |
    {apiVersion:"v1", kind:"Secret", type:"Opaque", metadata:{name:"petclinic-db-app",namespace:"petclinic"},
     data:({username,password,url:$url} | map_values(@base64))}' |
  kubectl apply --server-side --field-manager=petclinic-db-sync -f -
kubectl -n petclinic patch deployment api --type=strategic --patch-file deploy/database/api-db-patch.yaml
kubectl -n petclinic rollout status deployment/api --timeout=5m
```

첫 배포라면 `api-db-patch.yaml`의 환경 변수와 readiness probe를 WAS Deployment의 원본 매니페스트에 포함하고 위 Secret을 먼저 생성한다. 이미 배포된 WAS는 위 patch로 갱신할 수 있다. 이후 배포에도 같은 설정을 유지한다. 비밀번호 교체 시 DB 역할과 Secrets Manager 값을 함께 갱신한다. Terraform으로 Secret을 교체할 때는 `secret_string_wo_version`을 증가시킨다. Secret 동기화 후 환경 변수 값을 다시 읽도록 `kubectl -n petclinic rollout restart deployment/api`를 실행하고 롤아웃을 확인한다.

Proxy 타깃과 **실제 WAS의 DB 조회**를 모두 확인한다. 아래 포트 포워딩 동안 다른 터미널에서 readiness와 보호자 목록 API를 조회한다. 앱 인증이 활성화된 배포에서는 조회 권한이 있는 계정을 사용한다.

```bash
aws rds describe-db-proxy-targets --db-proxy-name petclinic-was-db-poc-proxy \
  --query 'Targets[].TargetHealth.{State:State,Reason:Reason}' --output table
kubectl -n petclinic port-forward deployment/api 19966:9966
```

```bash
curl -fsS http://127.0.0.1:19966/petclinic/actuator/health/readiness
curl -fsS 'http://127.0.0.1:19966/petclinic/api/v2/owners?page=0&size=1'
```

인수 기준은 Proxy 타깃 `AVAILABLE`, DB를 포함한 readiness `UP`, 보호자 조회 HTTP 200이다. 데이터가 없는 신규 DB의 목록은 비어 있을 수 있다.
