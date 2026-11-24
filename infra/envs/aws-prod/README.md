# AWS 운영 환경

`infra/envs/aws-prod/`는 서울과 오사카 리소스 및 글로벌 서비스를 함께 관리하는 Terraform 루트다. 운영 state는 오사카 S3 버킷 `petclinic-prod-tfstate-osaka`의 `petclinic/aws-prod/terraform.tfstate`에 저장하며 S3 잠금 파일을 사용한다. [루트 모듈 연결](main.tf) · [backend 설정](backend.tf) · [state 접근과 복구](../../STATE.md)

## 모듈 구성

| 루트 모듈 | 소유하는 자원 |
|---|---|
| [seoul_vpc1](seoul-vpc1-service/main.tf) | 서울 서비스 VPC, 앱·DB·퍼블릭 서브넷 각 2개, IGW·NAT, 오사카로 가는 앱 서브넷 경로 |
| [seoul_vpc2](seoul-vpc2-management/main.tf) | 서울 관리 VPC와 두 서브넷, 관리 IGW, [빌드·프라이빗 관리 EC2 모듈 연결](seoul-vpc2-management/servers.tf) |
| [osaka_observe](osaka-monitoring/main.tf) | 오사카 관제 VPC·서브넷, 서울 VPC 1과의 피어링 및 반환 경로, 향후 관제 EC2용 SSM IAM 구성 |
| [edge](edge/cloudfront.tf) | Route 53, CloudFront용 ACM 인증서, CloudFront 배포 및 EKS 내부 ALB 연결 시 생성하는 VPC Origin |

서울 VPC 1이 요청하고 오사카가 **같은 연결을 수락**한다. 서울의 두 앱 서브넷은 하나의 앱 테이블을 공유하므로 오사카 `10.40.0.0/27`행 경로도 하나다. 오사카 관제 서브넷의 테이블에는 서울 앱 대역 `10.10.0.0/24`·`10.10.1.0/24`행 경로가 각각 있다. 서울 DB·퍼블릭 서브넷과 서울 VPC 2에는 이 피어링 경로가 없다. [피어링 요청·수락과 오사카 경로](osaka-monitoring/peering.tf) · [서브넷 9개의 CIDR·AZ·태그·경로](SUBNET-RULES.md)

## 운영 입력과 출력

| 입력 | 값 |
|---|---|
| `aws_account_id` | 승인된 운영 AWS 계정의 12자리 ID |
| `aws_region` | `ap-northeast-2` |
| `availability_zones` | 서로 다른 서울 표준 AZ 2개. 운영 순서는 2a, 2c이며 관리 VPC의 두 서브넷은 첫 번째 AZ를 사용한다. |
| `eks_alb_arn` | 기본값은 `null`. EKS 내부 ALB가 준비되면 해당 ARN을 설정한다. |

| 작업 | 루트 출력 |
|---|---|
| 서비스 VPC 조회 및 EKS·DB 서브넷 전달 | `service_vpc_id`, `app_subnet_ids`, `db_subnet_ids`, `public_subnet_ids` |
| 관리 VPC 및 두 서브넷 조회 | `management_vpc_id`, `management_subnet_id`(프라이빗), `management_public_subnet_id`(퍼블릭) |
| SSM 접속 대상 조회 | `build_instance_id`, `management_instance_id` |
| 오사카 네트워크 조회 | `osaka_observe` 객체의 `vpc_id`, `subnet_id` |
| 서비스 진입점 조회 | `public_url`, `cloudfront_distribution_id`, `cloudfront_domain_name`, ALB 연결 후 `internal_alb_dns_name` |

`terraform output`은 운영 state에 반영된 값을 읽는다. 저장소 루트에서 `terraform -chdir=infra/envs/aws-prod output -json app_subnet_ids`를 실행하면 EKS 담당자가 사용할 두 앱 서브넷 ID를 AZ 입력 순서대로 얻는다. DB 담당자는 `db_subnet_ids`로 RDS 서브넷 그룹을 구성한다. [입력 검증](variables.tf) · [전체 출력 정의](outputs.tf)

## 도메인과 EKS 내부 ALB 연결

`mission-critical.site`의 기존 퍼블릭 호스팅 영역을 import하고 A·AAAA 별칭을 CloudFront로 연결한다. DNS 검증 CNAME과 `us-east-1`의 ACM 인증서를 관리한다. 기본값 `eks_alb_arn = null`에서는 CloudFront가 비활성이고 VPC Origin이 없다. 배포 구성의 임시 원본 이름은 `origin-pending.mission-critical.site`이며 해당 이름에 DNS 레코드는 생성하지 않는다. [영역 import](imports.tf) · [Route 53](edge/dns.tf) · [ACM과 DNS 검증](edge/acm.tf) · [CloudFront 배포](edge/cloudfront.tf) · [EKS ALB와 VPC Origin](edge/vpc-origin.tf)

1. EKS 담당자가 AWS Load Balancer Controller와 Ingress로 내부 ALB를 구성한다. Ingress에서 `alb.ingress.kubernetes.io/scheme`은 `internal`로, `alb.ingress.kubernetes.io/subnets`는 두 `app_subnet_ids`로 지정한다. 리스너·대상 그룹·백엔드 보안 설정도 EKS 담당 범위다.
2. ALB의 정상 대상과 HTTP 80 리스너를 확인하고, ALB 보안 그룹에서 CloudFront의 관리형 접두사 목록 `com.amazonaws.global.cloudfront.origin-facing`으로부터 TCP 80을 허용한다.
3. 운영 입력에 `eks_alb_arn`을 설정하고 plan에서 VPC Origin 생성과 배포 활성화를 확인한다. Terraform은 ALB가 서울 서비스 VPC 안의 내부 Application Load Balancer인지 검사한다. 적용 후 공개 도메인에서 실제 앱 응답을 확인한다.

별도 EKS 구성의 팀 인수 기준은 제어 영역·관리형 노드 Kubernetes 1.36, 노드 이미지 AL2023 x86_64, kubectl 1.36.x다. AMI 릴리스와 VPC CNI 빌드는 EKS 담당자가 서울에서 검증해 고정한다. Helm, Load Balancer Controller, Gateway API와 ESO 버전은 별도 통합 시험 대상이다. [EKS 담당자용 태그와 Ingress 예시](SUBNET-RULES.md)

## 서울 빌드·관리 서버

2026-11-23 기준 퍼블릭 빌드 EC2와 프라이빗 관리 EC2가 모두 실행 중이며 SSM에 온라인으로 등록돼 있다. 관리 서브넷의 인터페이스 엔드포인트 2개는 사용 가능하며 프라이빗 DNS가 활성화돼 있다. 관리 EC2의 SSM 경로와 VPC 1의 비공개 EKS API 경로는 별개다. EKS 접속에는 VPC 간 왕복 경로·DNS, TCP 443 보안 규칙, 클러스터 접근 권한이 추가로 필요하다. [서버별 사양·보안 그룹·SSM 접속 명령](seoul-vpc2-management/README.md)

## 검증과 배포

REST의 PostgreSQL 연결은 서울 앱 노드에서 RDS Proxy를 경유한다. 운영 적용 후 `database_connection` 출력으로 DB 역할과 스키마를 준비하고 API Deployment에 연결 정보를 전달한다. [DB 초기화와 EKS 앱 연결 검증](../../../deploy/database/README.md)

PR을 열면 Terraform 1.12.2로 `fmt`, `init -backend=false`, `validate`, AWS mock 테스트를 실행한다. 실제 운영 plan은 승인된 AWS 프로필로 S3 backend를 초기화한 디렉터리에서 실행한다. 배포 담당자는 계획의 생성·변경·삭제 대상을 확인한 후 저장한 plan을 적용한다. [CI 정의](../../../.github/workflows/terraform-check.yml) · [운영 backend 연결 절차](../../STATE.md)

CloudFront 원본을 연결할 때는 서울 서비스 서브넷의 여유 IP, VPC Origin 할당량과 서비스 연결 역할 권한을 확인한다. DNS에는 이미 위임된 운영 영역을 사용한다. [도메인 import](imports.tf) · [ALB 인수 절차](SUBNET-RULES.md)

빌드 서버 추가와 피어링 복원 이전 배치도는 참고용으로 보존한다. 현재 라우팅은 서브넷 문서를 기준으로 확인한다. [이전 전체 배치도](../../../docs/architecture/awsdac/overview.png) · [이전 서울 서비스망](../../../docs/architecture/awsdac/seoul-network.png) · [현재 서브넷과 라우팅](SUBNET-RULES.md)
