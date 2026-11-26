# AWS 운영 환경

`infra/envs/aws-prod/`는 서울 리소스 및 글로벌 서비스를 함께 관리하는 Terraform 루트다. 운영 state는 오사카 S3 버킷 `petclinic-prod-tfstate-osaka`의 `petclinic/aws-prod/terraform.tfstate`에 저장하며 S3 잠금 파일을 사용한다. [루트 모듈 연결](main.tf) · [backend 설정](backend.tf) · [state 접근과 복구](../../STATE.md)

## 모듈 구성

| 루트 모듈 | 소유하는 자원 |
|---|---|
| [seoul_vpc1](seoul-vpc1-service/main.tf) | 서울 서비스 VPC, 앱·DB·퍼블릭 서브넷 각 2개, IGW·NAT, 서울 관리 VPC로 가는 앱 서브넷 경로 |
| [seoul_vpc2](seoul-vpc2-management/main.tf) | 서울 관리 VPC와 두 서브넷, 관리 IGW, [빌드·프라이빗 관리 EC2 모듈 연결](seoul-vpc2-management/servers.tf) |
| [eks](eks/cluster.tf) | 비공개 EKS 클러스터, 관리형 노드 그룹, EKS 애드온, 관리자 접근 권한, 컨트롤러 IAM 역할 |
| [edge](cloudfront/cloudfront.tf) | Route 53, CloudFront용 미국 동부 ACM 인증서, ALB용 서울 ACM 인증서, CloudFront 배포 및 선택적 VPC Origin |

EKS 리소스의 기존 루트 주소와 `module.eks` 주소는 [moved 블록](moved.tf)으로 연결한다. CloudFront 모듈의 소스 경로는 `./cloudfront`, state 주소는 `module.edge`다.

서울 관리 VPC와 서비스 VPC는 피어링으로 연결된다. 앱 서브넷 두 개는 관리 VPC로 가는 경로를 공유한다. [서울 VPC 피어링](network-connections.tf) · [서브넷 8개의 CIDR·AZ·태그·경로](SUBNET-RULES.md)

## 운영 입력과 출력

| 입력 | 값 |
|---|---|
| `aws_account_id` | 승인된 운영 AWS 계정의 12자리 ID |
| `aws_region` | `ap-northeast-2` |
| `availability_zones` | 서로 다른 서울 표준 AZ 2개. 운영 순서는 2a, 2c이며 관리 VPC의 두 서브넷은 첫 번째 AZ를 사용한다. |
| `eks_alb_arn` | CloudFront VPC Origin 활성화 입력. EKS 담당자가 생성한 내부 ALB와 정상 앱 타깃을 확인할 때까지 기본값 `null`을 사용한다. |

| 작업 | 루트 출력 |
|---|---|
| 서비스 VPC 조회 및 EKS·DB 서브넷 전달 | `service_vpc_id`, `app_subnet_ids`, `db_subnet_ids`, `public_subnet_ids` |
| 관리 VPC 및 두 서브넷 조회 | `management_vpc_id`, `management_subnet_id`(프라이빗), `management_public_subnet_id`(퍼블릭) |
| EKS 관리 ALB의 HTTPS 443 인증서 | `seoul_alb_certificate_arn` |
| SSM 접속 대상 조회 | `build_instance_id`, `management_instance_id` |
| 서비스 진입점 조회 | `public_url`, `cloudfront_distribution_id`, `cloudfront_domain_name`, ALB 연결 후 `internal_alb_dns_name` |

`terraform output`은 운영 state에 반영된 값을 읽는다. 저장소 루트에서 `terraform -chdir=infra/envs/aws-prod output -json app_subnet_ids`를 실행하면 EKS 담당자가 사용할 두 앱 서브넷 ID를 AZ 입력 순서대로 얻는다. DB 담당자는 `db_subnet_ids`로 RDS 서브넷 그룹을 구성한다. [입력 검증](variables.tf) · [전체 출력 정의](outputs.tf)

## 도메인과 EKS 내부 ALB 연결

두 리전의 ACM 인증서와 공통 DNS 검증 CNAME에는 `prevent_destroy`를 설정했다. 이 리소스의 삭제나 교체가 포함되면 Terraform은 전체 계획을 거부한다. [인증서 삭제 보호](cloudfront/acm.tf)

`mission-critical.site`의 기존 퍼블릭 호스팅 영역을 import하고 A·AAAA 별칭을 CloudFront로 연결한다. DNS 검증 CNAME과 `us-east-1`의 ACM 인증서를 관리한다. 기본값 `eks_alb_arn = null`에서는 CloudFront가 비활성이고 VPC Origin이 없다. 배포 구성의 임시 원본 이름은 `origin-pending.mission-critical.site`이며 해당 이름에 DNS 레코드는 생성하지 않는다. [영역 import](imports.tf) · [Route 53](cloudfront/dns.tf) · [ACM과 DNS 검증](cloudfront/acm.tf) · [CloudFront 배포](cloudfront/cloudfront.tf) · [EKS ALB와 VPC Origin](cloudfront/vpc-origin.tf)

EKS 담당자가 AWS Load Balancer Controller를 통해 두 프라이빗 앱 서브넷에 내부 ALB를 생성하고 앱 타깃을 연결한다. 서울 ACM 인증서와 DNS 검증 CNAME은 이 Terraform 구성이 관리한다. 443 리스너에 사용할 인증서 ARN은 `terraform -chdir=infra/envs/aws-prod output -raw seoul_alb_certificate_arn`으로 조회한다. [인증서](cloudfront/acm.tf) · [운영 출력](outputs.tf)

CloudFront 활성화 전에는 새 ALB의 HTTPS 443 리스너, 앱 대상 그룹의 정상 타깃과 앱 응답을 확인한다. 현재 VPC Origin 정책은 `http-only`다. 443으로 전환할 때는 `https-only` 정책과 인증서가 유효한 오리진 호스트 이름을 구성한 뒤 `eks_alb_arn`을 지정한다. [VPC Origin 정책](cloudfront/vpc-origin.tf)

별도 EKS 구성의 팀 인수 기준은 제어 영역·관리형 노드 Kubernetes 1.36, 노드 이미지 AL2023 x86_64, kubectl 1.36.x다. AMI 릴리스와 VPC CNI 빌드는 EKS 담당자가 서울에서 검증해 고정한다. Helm, Load Balancer Controller, Gateway API와 ESO 버전은 별도 통합 시험 대상이다. [EKS 담당자용 서브넷·ALB 인수 정보](SUBNET-RULES.md)

## 서울 빌드·관리 서버

2026-11-23 기준 퍼블릭 빌드 EC2와 프라이빗 관리 EC2가 모두 실행 중이며 SSM에 온라인으로 등록돼 있다. 관리 서브넷의 인터페이스 엔드포인트 2개는 사용 가능하며 프라이빗 DNS가 활성화돼 있다. 관리 EC2의 SSM 경로와 VPC 1의 비공개 EKS API 경로는 별개다. EKS 접속에는 VPC 간 왕복 경로·DNS, TCP 443 보안 규칙, 클러스터 접근 권한이 추가로 필요하다. [서버별 사양·보안 그룹·SSM 접속 명령](seoul-vpc2-management/README.md)

## 검증과 배포

PR을 열면 Terraform 1.12.2로 `fmt`, `init -backend=false`, `validate`, AWS mock 테스트를 실행한다. 실제 운영 plan은 승인된 AWS 프로필로 S3 backend를 초기화한 디렉터리에서 실행한다. 배포 담당자는 계획의 생성·변경·삭제 대상을 확인한 후 저장한 plan을 적용한다. [CI 정의](../../../.github/workflows/terraform-check.yml) · [운영 backend 연결 절차](../../STATE.md)

오사카 관제 VPC를 폐기할 때는 운영 plan에서 `module.osaka_observe`의 네트워크·전용 SSM IAM 리소스 삭제와 서울 앱 라우팅 테이블의 `10.40.0.0/27` 경로 제거를 확인한다. 서울 관리망 피어링 경로 `10.20.0.0/24`와 NAT 기본 경로는 계속 사용한다. 적용 후 `terraform state list module.osaka_observe`가 비면 정리용 `aws.osaka` provider 설정도 제거할 수 있다. 운영 state는 계속 오사카 S3 버킷에 저장한다. [provider 설정](providers.tf) · [운영 backend](backend.tf)

CloudFront 원본을 연결할 때는 서울 서비스 서브넷의 여유 IP, VPC Origin 할당량과 서비스 연결 역할 권한을 확인한다. DNS에는 이미 위임된 운영 영역을 사용한다. [도메인 import](imports.tf) · [ALB 인수 절차](SUBNET-RULES.md)

빌드 서버 추가와 피어링 복원 이전 배치도는 참고용으로 보존한다. 현재 라우팅은 서브넷 문서를 기준으로 확인한다. [이전 전체 배치도](../../../docs/architecture/awsdac/overview.png) · [이전 서울 서비스망](../../../docs/architecture/awsdac/seoul-network.png) · [현재 서브넷과 라우팅](SUBNET-RULES.md)
