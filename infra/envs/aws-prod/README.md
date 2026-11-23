# AWS 운영 환경: mission-critical.site

Terraform 실행 위치는 이 디렉터리다. [main.tf](main.tf)에서 네 모듈의 입력과 연결을 한 번에 볼 수 있다.

| 디렉터리 | 관리하는 구성 |
|---|---|
| [seoul-vpc1-service/](seoul-vpc1-service/main.tf) | 서울 VPC 1의 앱·DB·퍼블릭 서브넷, NAT와 앱 서브넷의 오사카 경로 |
| [seoul-vpc2-management/](seoul-vpc2-management/main.tf) | 서울 VPC 2의 관리·빌드 서브넷, IGW와 [빌드 EC2](seoul-vpc2-management/build-server/main.tf) |
| [edge/](edge/) | Route 53·ACM, CloudFront와 EKS 관리형 ALB에 대한 선택적 VPC Origin |
| [osaka-monitoring/](osaka-monitoring/) | 오사카 VPC·서브넷, 서울 VPC 1 피어링과 향후 EC2용 SSM IAM 역할·정책·인스턴스 프로필 |
| [tests/](tests/) | 환경·모듈별 mock plan 테스트. [mocks/](tests/mocks/)에 AWS 모의 응답을 둔다. |

서울 VPC 1의 두 앱 서브넷과 오사카 관제 서브넷이 피어링을 사용한다. 요청·수락과 오사카 쪽 반환 경로는 [피어링 구성](osaka-monitoring/peering.tf)에 있다. `osaka_observe` 출력은 VPC ID와 서브넷 ID를 제공한다. 루트의 [variables.tf](variables.tf)와 [outputs.tf](outputs.tf)는 운영자가 쓰는 입력·출력이고, [providers.tf](providers.tf)는 모듈에 전달할 AWS 계정·리전을 설정한다. [backend.tf](backend.tf)는 서울과 오사카를 함께 기록하는 운영 환경의 S3 state를 설정한다. 기존 Route 53 영역을 연결하는 주소는 [imports.tf](imports.tf), 모듈화 전후 state 주소는 [moved.tf](moved.tf)에서 확인한다.

[빌드 서버·피어링 복원 전 토폴로지](../../../docs/architecture/awsdac/overview.png) · [피어링 복원 전 서울 서비스망](../../../docs/architecture/awsdac/seoul-network.png)

## 도메인과 앱 요청 경로

Route 53의 A·AAAA 별칭은 CloudFront를 가리킨다. 배포는 `us-east-1`의 ACM 인증서와 DNS 검증 CNAME을 유지한다. 기본값 `eks_alb_arn = null`에서는 배포가 비활성 상태다. CloudFront가 필수로 요구하는 원본 이름에는 `origin-pending.mission-critical.site`를 사용하며, 이 이름의 DNS 레코드는 만들지 않는다.

서비스를 시작할 때는 다음 순서로 연결한다.

1. EKS 담당자가 AWS Load Balancer Controller와 `Ingress`로 서울 서비스 VPC에 내부 ALB를 만든다. Ingress에 `alb.ingress.kubernetes.io/scheme: internal`과 `alb.ingress.kubernetes.io/subnets`로 두 `app_subnet_ids`를 명시한다. 리스너, 웹·API 라우팅과 헬스 체크, 대상 그룹, ALB 및 백엔드 보안 설정은 EKS 쪽에서 관리한다.
2. ALB의 HTTP 80 리스너와 정상 대상을 확인한다. ALB 보안 그룹은 서울의 AWS 관리형 접두사 목록 `com.amazonaws.global.cloudfront.origin-facing`에서 TCP 80을 허용한다. CloudFront에서 ALB까지는 VPC Origin을 통한 HTTP 연결이다.
3. 운영 입력에 `eks_alb_arn`을 설정해 계속 유지한다. plan에서 기존 ALB 조회, VPC Origin 생성, 기존 CloudFront 배포 활성화를 확인한 뒤 적용한다. 공개 도메인에서 실제 앱 응답까지 검증한다. 이 입력을 다시 해제하면 배포가 비활성화된다.

## EKS·데이터베이스 담당자에게 전달할 값

서브넷 9개의 CIDR·AZ·라우팅, `component`와 `Name` 생성식, Ingress에 앱 서브넷 ID를 연결하는 예시는 [서브넷과 EKS 연결 규칙](SUBNET-RULES.md)에 있다.

이 루트는 서울 네트워크와 앱 진입점을 관리한다. EKS 클러스터·워커와 RDS 인스턴스·DB 서브넷 그룹은 각 담당자가 별도로 구성한다. 네트워크를 적용한 뒤 [루트 출력](outputs.tf)에서 연결 값을 확인할 수 있다.

| 담당 | 사용할 출력 | 담당 코드에서 연결할 작업 |
|---|---|---|
| EKS | `service_vpc_id`, `app_subnet_ids` | 두 앱 서브넷에 내부 ALB를 생성하고 해당 ARN을 운영 루트의 `eks_alb_arn`으로 전달한다. |
| 데이터베이스 | `service_vpc_id`, `db_subnet_ids` | 기존 DB 서브넷으로 RDS 서브넷 그룹을 만들고 EKS 담당자와 DB 접근 보안 그룹 규칙을 연결한다. |

EKS 인수 기준은 제어 영역·관리형 노드 Kubernetes **1.36**, 노드 이미지 **AL2023 x86_64**, kubectl **1.36.x**다. 정확한 AMI 릴리스와 VPC CNI 빌드는 EKS 담당자가 서울 리전에서 검증한 뒤 고정한다. Helm·LBC·Gateway API·ESO 버전은 별도 통합 시험 대상이다.

## 서울 빌드 서버

관리 VPC의 `management_subnet_id`는 로컬 경로만 있는 기존 프라이빗 서브넷이고, `management_public_subnet_id`는 빌드 EC2를 둔 `10.20.0.32/27`이다. 빌드 서브넷은 전용 IGW를 통해 인터넷에 연결된다. 공인 IPv4는 인스턴스에만 할당하며 중지 후 다시 시작하면 바뀔 수 있다. 오사카 네트워크는 `osaka_observe`로 조회한다. [서울·오사카 라우팅](OSAKA-VPC2.md)

로컬 AWS CLI에 Session Manager 플러그인을 설치하고 세션 권한이 있는 프로필로 저장소 루트에서 접속한다.

```sh
instance_id=$(terraform -chdir=infra/envs/aws-prod output -raw build_instance_id)
aws ssm start-session --profile default --region ap-northeast-2 --target "$instance_id"
```

서버는 Canonical Ubuntu 24.04 LTS 기본 이미지로 시작한다. Terraform은 추가 패키지를 설치하는 user data를 전달하지 않는다. 보안 그룹 인바운드는 비어 있고 아웃바운드는 TCP 80·443만 허용한다. 빌드 서버를 중지하면 루트 디스크의 데이터는 보존된다. Terraform으로 인스턴스를 교체하거나 종료하면 이 루트 디스크도 삭제된다.

## 실제 plan 전 확인

- `aws_account_id`(승인된 12자리 계정), `aws_region = "ap-northeast-2"`, `availability_zones`(그 계정에서 사용 가능한 서로 다른 서울 표준 AZ 두 개)를 입력한다. 도메인과 ACM 리전은 고정값이다.
- 승인된 임시 자격 증명으로 계정을 확인하고 [공유 state 절차](../../STATE.md)에 따라 실제 버킷·리전·잠금 권한을 확인한다. 기존 도쿄 백엔드 override를 제거하고 이 디렉터리에서 `terraform init -reconfigure -input=false`로 오사카에 연결한 뒤 `terraform state list`를 확인한다. 워크로드 변경이 필요할 때만 `terraform plan`을 실행한다. 계정 값, 자격 증명, backend.hcl, tfvars, state, plan은 커밋하지 않는다.
- 역할에는 state 접근 외에 두 리전과 글로벌 서비스 조회 권한이 필요하다. 대상 계정에서 `mission-critical.site` 퍼블릭 영역이 유일하며 등록기관의 NS 위임이 일치하는지 확인한다. 기존 apex/검증 레코드나 다른 CloudFront 배포의 별칭과 충돌하면 덮어쓰지 말고 소유자와 이전·import를 협의한다.
- 실제 배포 전에는 서비스 연결 역할과 VPC origin ENI 생성 권한, 서브넷 여유 IP, ALB·VPC origin 할당량, 서울에서의 관리형 접두사 목록 가용성 및 SG 인바운드 할당량(목록 가중치 55)을 확인한다. mock plan은 DNS 위임이나 AWS API 수락 여부를 검증하지 않는다.
- 비공개 EKS API에 접속하는 관리 호스트에는 별도의 IAM 권한과 API 왕복 경로가 필요하다. 빌드 EC2는 SSM용 역할을 사용한다.
- DMS와 타 클라우드 복제는 포함하지 않는다. 서울 앱 서브넷 두 곳은 기존 단일 NAT를 공유한다.

루트 출력은 `outputs.tf`에 있다. 기존 네트워크 ID에 더해 `public_url`, `cloudfront_distribution_id`, `cloudfront_domain_name`, EKS ALB 연결 시 `internal_alb_dns_name`을 제공한다.
