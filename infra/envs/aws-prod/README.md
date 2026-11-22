# AWS 운영 환경: mission-critical.site

기존 퍼블릭 Route 53 영역에서 apex의 A·AAAA 별칭은 CloudFront 배포를 가리킨다. us-east-1 ACM 인증서의 DNS 검증 CNAME은 자동 갱신에도 필요하므로 유지한다. HTTP 뷰어는 HTTPS로 리디렉션되며 최소 TLS 1.2를 사용한다. GET/HEAD만 허용하고 `Managed-CachingDisabled` 정책을 적용한다.

**암호화 경계:** TLS는 CloudFront에서 종료한다. CloudFront VPC origin에서 서울 서비스 VPC의 내부 ALB까지는 사설 IPv4 경로의 **평문 HTTP:80**이다. ALB는 두 앱 서브넷에 있고, 보안 그룹은 AWS 관리형 CloudFront origin-facing 접두사 목록에서 오는 TCP/80만 허용한다. 이 목록은 특정 배포 전용이 아니며 종단 간 TLS나 요청 인증을 대신하지 않는다. 인증 정보나 민감한 앱 데이터를 전달하기 전에는 이 경계를 재검토한다. 서비스 VPC에는 DNS support/hostnames 및 연결된 IGW가 필요하지만 ALB를 퍼블릭 서브넷에 둘 필요는 없다.

`https://mission-critical.site/health`는 ALB 고정 응답 200, 그 외 경로는 기본 404다. `/health`는 엣지에서 리스너까지의 확인용이지 앱 상태 검사가 아니다. EKS나 대상 그룹은 생성하지 않는다.

## 실제 plan 전 확인

- `aws_account_id`(승인된 12자리 계정), `aws_region = "ap-northeast-2"`, `availability_zones`(그 계정에서 사용 가능한 서로 다른 서울 표준 AZ 두 개)를 입력한다. 도메인과 ACM 리전은 고정값이다.
- 승인된 임시 자격 증명으로 계정을 확인하고 [공유 state 절차](../../STATE.md)에 따라 실제 버킷·리전·잠금 권한을 확인한다. 기존 도쿄 백엔드 override를 제거하고 이 디렉터리에서 `terraform init -reconfigure -input=false`로 오사카에 연결한 뒤 `terraform state list`를 확인한다. 워크로드 변경이 필요할 때만 `terraform plan`을 실행한다. 계정 값, 자격 증명, backend.hcl, tfvars, state, plan은 커밋하지 않는다.
- 역할에는 state 접근 외에 두 리전과 글로벌 서비스 조회 권한이 필요하다. 대상 계정에서 `mission-critical.site` 퍼블릭 영역이 유일하며 등록기관의 NS 위임이 일치하는지 확인한다. 기존 apex/검증 레코드나 다른 CloudFront 배포의 별칭과 충돌하면 덮어쓰지 말고 소유자와 이전·import를 협의한다.
- 실제 배포 전에는 서비스 연결 역할과 VPC origin ENI 생성 권한, 서브넷 여유 IP, ALB·VPC origin 할당량, 서울에서의 관리형 접두사 목록 가용성 및 SG 인바운드 할당량(목록 가중치 55)을 확인한다. mock plan은 DNS 위임이나 AWS API 수락 여부를 검증하지 않는다.

루트 출력은 `outputs.tf`에 있다. 기존 네트워크 ID에 더해 `public_url`, `cloudfront_distribution_id`, `cloudfront_domain_name`, `internal_alb_dns_name`을 제공한다.
