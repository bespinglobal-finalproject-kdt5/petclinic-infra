# AWS 운영 환경: mission-critical.site

기존 Route 53 영역에서 apex의 A·AAAA 별칭을 CloudFront에 연결한다. us-east-1 ACM 인증서의 검증 CNAME을 보존한다. UI는 GET/HEAD, `/petclinic/api/*`는 HTTPS와 CRUD 메서드를 허용하며 둘 다 캐시를 끈다. 뷰어 함수는 `demo_viewer_ipv4`에 명시한 개별 공인 IPv4만 허용한다(기본 빈 목록은 모두 403). 이 데모에 실제 고객 데이터를 넣지 않는다.

**암호화 경계:** TLS는 CloudFront에서 종료한다. CloudFront VPC origin에서 서울 서비스 VPC의 내부 ALB까지는 사설 IPv4 경로의 **평문 HTTP:80**이다. ALB는 두 앱 서브넷에 있고, 보안 그룹은 AWS 관리형 CloudFront origin-facing 접두사 목록에서 오는 TCP/80만 허용한다. 이 목록은 특정 배포 전용이 아니며 종단 간 TLS나 요청 인증을 대신하지 않는다. 인증 정보나 민감한 앱 데이터를 전달하기 전에는 이 경계를 재검토한다. 서비스 VPC에는 DNS support/hostnames 및 연결된 IGW가 필요하지만 ALB를 퍼블릭 서브넷에 둘 필요는 없다.

`/health`는 기존 ALB의 고정 200이므로 앱 배포 성공 기준이 아니다. API는 별도 대상 그룹(NodePort 30966), UI는 기본 경로 대상 그룹(30080)을 쓴다. 노드 그룹의 ASG가 EC2 대상을 등록한다. 인프라 적용만으로 Pod가 기동하지 않는다. 조직 GHCR에 웹·API 이미지를 게시한 뒤 그 digest로 [Kubernetes 배포](../../../deploy/k8s/README.md)를 수행한다. 두 대상 그룹과 허용 IP에서 실제 API를 확인한다. 원래 plan으로 생성된 ECR 저장소는 앱 배포에 사용하지 않으며 별도의 정리 승인 없이 삭제하지 않는다.

## 실제 plan 전 확인

- `aws_account_id`(승인된 12자리 계정), `aws_region = "ap-northeast-2"`, `availability_zones`(그 계정에서 사용 가능한 서로 다른 서울 표준 AZ 두 개)를 입력한다. 도메인과 ACM 리전은 고정값이다.
- 승인된 임시 자격 증명으로 계정을 확인하고 [공유 state 절차](../../STATE.md)에 따라 실제 버킷·리전·잠금 권한을 확인한다. 이 디렉터리에서 `terraform init -backend-config=backend.hcl -input=false` 후 `terraform plan`을 실행한다. 계정 값, 자격 증명, backend.hcl, tfvars, state, plan은 커밋하지 않는다.
- 역할에는 state 접근 외에 두 리전과 글로벌 서비스 조회 권한이 필요하다. 대상 계정에서 `mission-critical.site` 퍼블릭 영역이 유일하며 등록기관의 NS 위임이 일치하는지 확인한다. 기존 apex/검증 레코드나 다른 CloudFront 배포의 별칭과 충돌하면 덮어쓰지 말고 소유자와 이전·import를 협의한다.
- 실제 배포 전에는 서비스 연결 역할과 VPC origin ENI 생성 권한, 서브넷 여유 IP, ALB·VPC origin 할당량, 서울에서의 관리형 접두사 목록 가용성 및 SG 인바운드 할당량(목록 가중치 55)을 확인한다. mock plan은 DNS 위임이나 AWS API 수락 여부를 검증하지 않는다.
- 비공개 API 접속: SSM managed instance가 Online이 된 뒤 `CLUSTER`, `MANAGER_ID`, `TUNNEL_KUBECONFIG`(아직 존재하지 않는 경로)를 설정해 `bash deploy/eks-tunnel.sh`를 저장소 루트에서 실행한다. 다른 터미널에서 안내된 `KUBECONFIG`로 `kubectl get nodes`를 확인한다. SSM 터널은 네트워크 경로일 뿐이고 Kubernetes 권한은 접속자의 EKS Access Entry로 검증된다.
- DMS와 타 클라우드 복제는 포함하지 않는다. 기존 단일 NAT를 재사용하므로 워크로드 두 AZ와 RDS Multi-AZ가 모든 네트워크 구성의 이중화를 의미하지 않는다.

루트 출력은 `outputs.tf`에 있다. 기존 네트워크 ID에 더해 `public_url`, `cloudfront_distribution_id`, `cloudfront_domain_name`, `internal_alb_dns_name`을 제공한다.
