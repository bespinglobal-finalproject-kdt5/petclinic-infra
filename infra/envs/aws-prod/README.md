# AWS 운영 환경: mission-critical.site

기존 Route 53 영역에서 apex의 A·AAAA 별칭을 CloudFront에 연결한다. us-east-1 ACM 인증서의 검증 CNAME을 보존한다. UI는 GET/HEAD, `/petclinic/api/*`는 HTTPS와 CRUD 메서드를 허용하며 둘 다 캐시를 끈다. 웹과 API는 IP 제한이나 로그인 없이 공개한다. 누구나 등록·수정·삭제할 수 있는 가상 데이터 전용 데모다. 이 데모에 실제 고객 데이터를 넣지 않는다.

**암호화 경계:** TLS는 CloudFront에서 종료한다. CloudFront VPC origin에서 서울 서비스 VPC의 내부 ALB까지는 사설 IPv4 경로의 **평문 HTTP:80**이다. ALB는 두 앱 서브넷에 있고, 보안 그룹은 AWS 관리형 CloudFront origin-facing 접두사 목록에서 오는 TCP/80만 허용한다. 이 목록은 특정 배포 전용이 아니며 종단 간 TLS나 요청 인증을 대신하지 않는다. 인증 정보나 민감한 앱 데이터를 전달하기 전에는 이 경계를 재검토한다. 서비스 VPC에는 DNS support/hostnames 및 연결된 IGW가 필요하지만 ALB를 퍼블릭 서브넷에 둘 필요는 없다.

`/health`는 기존 ALB의 고정 200이므로 앱 배포 성공 기준이 아니다. API는 별도 대상 그룹(NodePort 30966), UI는 기본 경로 대상 그룹(30080)을 쓴다. 노드 그룹의 ASG가 EC2 대상을 등록한다. 인프라 적용만으로 Pod가 기동하지 않는다. ECR 이미지 업로드 후 [Kubernetes 배포](../../../deploy/k8s/README.md)를 수행하고, 두 대상 그룹이 healthy인지와 일반 인터넷 연결에서 인증 없이 가상 데이터의 API 조회·등록이 되는지를 확인한다. Pod가 준비되기 전에는 도메인에서 503을 반환할 수 있다.

## 서울 관리 VPC 2 / 오사카 관제망

`management_vpc_id`와 `management_subnet_id`는 서울의 격리된 관리 네트워크다. `osaka_observe`는 별도 Grafana 관제망이다. [역할·경로·복원 범위](OSAKA-VPC2.md)를 참고한다.

## 실제 plan 전 확인

- `aws_account_id`(승인된 12자리 계정), `aws_region = "ap-northeast-2"`, `availability_zones`(그 계정에서 사용 가능한 서로 다른 서울 표준 AZ 두 개)를 입력한다. 도메인과 ACM 리전은 고정값이다.
- 승인된 임시 자격 증명으로 계정을 확인하고 [공유 state 절차](../../STATE.md)에 따라 실제 버킷·리전·잠금 권한을 확인한다. 기존 도쿄 백엔드 override를 제거하고 이 디렉터리에서 `terraform init -reconfigure -input=false`로 오사카에 연결한 뒤 `terraform state list`를 확인한다. 워크로드 변경이 필요할 때만 `terraform plan`을 실행한다. 계정 값, 자격 증명, backend.hcl, tfvars, state, plan은 커밋하지 않는다.
- 역할에는 state 접근 외에 두 리전과 글로벌 서비스 조회 권한이 필요하다. 대상 계정에서 `mission-critical.site` 퍼블릭 영역이 유일하며 등록기관의 NS 위임이 일치하는지 확인한다. 기존 apex/검증 레코드나 다른 CloudFront 배포의 별칭과 충돌하면 덮어쓰지 말고 소유자와 이전·import를 협의한다.
- 실제 배포 전에는 서비스 연결 역할과 VPC origin ENI 생성 권한, 서브넷 여유 IP, ALB·VPC origin 할당량, 서울에서의 관리형 접두사 목록 가용성 및 SG 인바운드 할당량(목록 가중치 55)을 확인한다. mock plan은 DNS 위임이나 AWS API 수락 여부를 검증하지 않는다.
- 서울 관리 호스트와 EKS를 별도 배포한 경우에만 `AWS_REGION=ap-northeast-2`, `CLUSTER`, 서울의 `MANAGER_ID`, `TUNNEL_KUBECONFIG`로 `deploy/eks-tunnel.sh`를 사용한다. 네트워크만 복원하는 이번 단계에는 호스트·접속 권한·클러스터가 없다. 오사카 관제 VM을 대신 사용하지 않는다.
  **주의:** 전체 `terraform apply`는 롤백된 서울 EKS·RDS·CloudFront 등을 새로 만들 수 있다. 서울 관리망 4개만 포함하는 복원 plan을 전체 계획과 구분한다.
- DMS와 타 클라우드 복제는 포함하지 않는다. 기존 단일 NAT를 재사용하므로 워크로드 두 AZ와 RDS Multi-AZ가 모든 네트워크 구성의 이중화를 의미하지 않는다.

루트 출력은 `outputs.tf`에 있다. 기존 네트워크 ID에 더해 `public_url`, `cloudfront_distribution_id`, `cloudfront_domain_name`, `internal_alb_dns_name`을 제공한다.
