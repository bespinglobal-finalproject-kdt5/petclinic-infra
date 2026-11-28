# AWS 운영 환경

`infra/envs/aws-prod/`는 서울 리소스 및 글로벌 서비스를 함께 관리하는 Terraform 루트다. 운영 state는 서울 S3 버킷 `petclinic-prod-tfstate-seoul`의 `petclinic/aws-prod/terraform.tfstate`에 저장하며 S3 잠금 파일을 사용한다. [루트 모듈 연결](main.tf) · [backend 설정](backend.tf) · [state 접근과 복구](../../STATE.md)

## 모듈 구성

각 모듈은 사용하는 조회를 자체 `data.tf`에 모은다. 루트는 기존 Route 53 공개 호스팅 영역을 조회해 CloudFront 모듈로 import한다. 모듈의 A·AAAA 별칭과 ACM 검증 CNAME은 이 영역을 직접 참조한다. [루트 조회](data.tf) · [CloudFront 정책·ALB·원본 IP 대역 목록](cloudfront/data.tf) · [EKS 네트워크·OIDC](eks/data.tf) · [관리 VPC의 Ubuntu AMI](seoul-vpc2-management/data.tf) · [영역 import](imports.tf) · [루트 출력](outputs.tf)

| 하위 모듈 | 관리하는 자원 |
|---|---|
| [seoul_vpc1](seoul-vpc1-service/main.tf) | 서울 서비스 VPC, 앱·DB·퍼블릭 서브넷 각 2개, IGW·NAT, 피어링 반환 경로, [Azure DR용 NLB와 보안 규칙](seoul-vpc1-service/azure-dr-nlb.tf), [Multi-AZ RDS PostgreSQL](seoul-vpc1-service/rds-database.tf) |
| [seoul_vpc2](seoul-vpc2-management/main.tf) | 서울 관리 VPC와 두 서브넷, 관리 IGW·NAT, 빌드·관리 EC2, SSM 엔드포인트. [EC2 모듈 연결](seoul-vpc2-management/servers.tf) |
| [connectivity](connectivity/) | 서울 VPC 간 피어링과 양방향 DNS 해석 옵션, 관리 EC2·EKS·RDS 간 보안 그룹 규칙 |
| [eks](eks/cluster.tf) | 비공개 EKS 클러스터, 관리형 노드 그룹, EKS 애드온, 관리자 접근 권한, 컨트롤러 IAM 역할 |
| [cloudfront](cloudfront/cloudfront.tf) | Route 53, CloudFront용 미국 동부 ACM 인증서, ALB용 서울 ACM 인증서, CloudFront 배포 및 선택적 VPC Origin |

기존 서울 운영 state를 사용하는 배포 담당자는 모듈 분리 전 주소가 남아 있는지 확인한다. 아래 state 관리 문서의 주소표로 이전한 뒤 전체 plan에서 AWS 리소스 생성·변경·삭제가 각각 0건인지 확인한다. [서울 운영 state 주소 이전](../../STATE.md#서울-모듈-주소-이전)

`connectivity` 모듈은 관리 EC2에서 피어링을 거쳐 EKS API(TCP 443)와 RDS(TCP 5432)로 가는 규칙을 연결한다. 같은 서비스 VPC 안에서 RDS로 접속하는 EKS 워크로드에는 EKS 클러스터 보안 그룹을 출발지로 허용한다. [모듈 간 보안 그룹 규칙](connectivity/security-groups.tf) · [관리 역할의 EKS 권한](management-access.tf) · [서브넷별 경로](SUBNET-RULES.md)

## 운영 입력과 출력

새 체크아웃은 이 디렉터리에서 `cp terraform.tfvars.example terraform.tfvars`로 시작한다. 계정 ID를 운영값으로 바꾸고 노드·애드온 버전을 확인한다. 승인된 EKS 관리자 ARN 목록은 로컬 `terraform.tfvars` 또는 기존 `terraform.tfvars.json`에 `admin_principal_arns`로 지정한다. Git에는 예시 파일만 포함한다. [입력 예시](terraform.tfvars.example)

| 입력 | 값 |
|---|---|
| `aws_account_id` | 승인된 운영 AWS 계정의 12자리 ID |
| `aws_region` | `ap-northeast-2` |
| `availability_zones` | 서로 다른 서울 표준 AZ 2개. 운영 순서는 2a, 2c이며 관리 VPC의 두 서브넷은 첫 번째 AZ를 사용한다. |
| `node_release_version`, `addon_versions` | 필수 입력. 서울에서 사용할 노드 AMI 릴리스와 `vpc-cni`, `coredns`, `kube-proxy`, `metrics-server`의 빌드 버전을 지정한다. |
| `cluster_name`, `kubernetes_version`, `node_instance_type`, `node_scaling` | 기본값은 `petclinic-prod-eks`, Kubernetes 1.36, `t3.medium`, 최소 2·희망 2·최대 4대다. |
| `admin_principal_arns` | 필수 입력. 운영자가 관리할 IAM 사용자·역할 ARN 목록이다. 관리 EC2 역할은 루트가 자동으로 추가한다. |
| `db_master_password` | RDS 마스터 계정의 비밀번호 입력. DB 모듈의 쓰기 전용 인수로 전달한다. |
| `eks_alb_arn` | 내부 ALB의 ARN. 지정하면 해당 ALB용 HTTPS VPC Origin을 준비한다. 기본값은 `null`이다. |
| `cloudfront_enabled` | 기본값은 `false`다. `true`로 설정하면 준비된 VPC Origin을 배포에 연결하고 도메인 트래픽을 받는다. |

| 작업 | 루트 출력 |
|---|---|
| 서비스 VPC 조회 및 EKS·DB 서브넷 전달 | `service_vpc_id`, `app_subnet_ids`, `db_subnet_ids`, `public_subnet_ids` |
| 관리 VPC 및 두 서브넷 조회 | `management_vpc_id`, `management_subnet_id`(프라이빗), `management_public_subnet_id`(퍼블릭) |
| EKS 관리 ALB의 HTTPS 443 인증서 | `seoul_alb_certificate_arn` |
| EKS 클러스터 이름, 관리 역할과 컨트롤러 IAM 역할 확인 | `eks_manual_values` |
| SSM 접속 대상 조회 | `build_instance_id`, `management_instance_id` |
| 서비스 진입점 조회 | `public_url`, `cloudfront_distribution_id`, `cloudfront_domain_name`, ALB 연결 후 `internal_alb_dns_name` |

`terraform output`은 운영 state에 반영된 값을 읽는다. 저장소 루트에서 `terraform -chdir=infra/envs/aws-prod output -json app_subnet_ids`를 실행하면 두 앱 서브넷 ID를 AZ 입력 순서대로 얻는다. EKS 모듈은 이 서브넷을 입력받고, 서비스 VPC 모듈은 두 DB 서브넷으로 RDS 서브넷 그룹을 구성한다. [입력 검증](variables.tf) · [루트 출력](outputs.tf) · [DB 서브넷 그룹](seoul-vpc1-service/rds-subnets-group.tf)

## 서비스 진입점과 CloudFront 전환

11월 28일 기준 공개 ALB의 HTTP 80과 내부 ALB의 HTTPS 443 대상 그룹은 모두 정상이다. Route 53의 `mission-critical.site` A·AAAA 별칭은 CloudFront를 가리킨다. [Route 53](cloudfront/dns.tf)

운영 입력의 `eks_alb_arn`은 기존 내부 ALB를 지정한다. VPC Origin은 `https-only`로 배포돼 있고, `cloudfront_enabled = false`이므로 배포는 비활성 상태다. 이때 원본은 `origin-pending.mission-critical.site`이고 기본 경로에는 원본 요청 정책이 없다. API 경로에는 `Managed-AllViewerExceptHostHeader`를 사용한다. [배포 설정](cloudfront/cloudfront.tf) · [VPC Origin](cloudfront/vpc-origin.tf)

전환할 때는 내부 ALB의 인증서와 서비스 도메인의 Host 헤더로 웹·API 응답을 확인한다. `eks_alb_arn`을 유지하고 `cloudfront_enabled = true`로 plan하면 배포를 활성화하고 두 경로 모두 `Managed-AllViewer`로 뷰어의 Host를 전달한다. 서울 ALB와 미국 동부 뷰어 인증서 및 공통 DNS 검증 CNAME에는 삭제 보호가 설정돼 있다. [인증서](cloudfront/acm.tf)

## Azure DR에서 RDS로 가는 경로

공개 `AWS-Azure` NLB는 서비스 VPC의 두 퍼블릭 서브넷에 걸쳐 있으며 교차 영역 로드 밸런싱을 사용한다. NLB 보안 그룹은 Azure NAT의 고정 IPv4 하나에서 오는 TCP 5432를 허용한다. RDS 보안 그룹은 NLB 보안 그룹에서 오는 같은 포트를 허용한다. 타깃 그룹은 TCP 상태 검사를 사용한다. [NLB와 보안 그룹](seoul-vpc1-service/azure-dr-nlb.tf)

NLB는 RDS 사설 IP를 등록한다. Terraform은 plan 시 주 DB의 AZ, DB 서브넷, 전용 보안 그룹을 기준으로 RDS 네트워크 인터페이스를 조회한다. RDS 장애 조치 후에는 `terraform plan`에서 등록 대상 변경을 확인하고 적용한 뒤 NLB 타깃의 `healthy` 상태와 Azure 쪽 접속을 확인한다. 장애 조치 자체가 Terraform 실행을 시작하지는 않는다.

EKS 모듈은 AL2023 x86_64 관리형 노드 그룹, EKS 애드온 4개, AWS Load Balancer Controller와 Cluster Autoscaler용 IAM 역할을 관리한다. Angular와 Spring REST 소스는 팀의 애플리케이션 저장소에 있다. [노드 그룹](eks/nodes.tf) · [애드온](eks/addons.tf) · [컨트롤러 IAM](eks/controllers.tf) · [애플리케이션 소스](https://github.com/bespinglobal-finalproject-kdt5/petclinic-eks-app)

## 서울 빌드·관리 서버

퍼블릭 빌드 EC2에는 EIP를 연결한다. 프라이빗 관리 EC2는 SSM 엔드포인트로 운영 세션을 열고, 서비스 VPC 피어링으로 EKS API와 PostgreSQL에 접근한다. [서버별 사양·보안 그룹·SSM 접속 명령](seoul-vpc2-management/README.md)

## 검증과 배포

PR을 열면 Terraform 1.12.2로 `fmt`, `init -backend=false`, `validate`, AWS mock 테스트를 실행한다. 실제 운영 plan은 승인된 AWS 프로필로 S3 backend를 초기화한 디렉터리에서 실행한다. 배포 담당자는 계획의 생성·변경·삭제 대상을 확인한 후 저장한 plan을 적용한다. [CI 정의](../../../.github/workflows/terraform-check.yml) · [운영 backend 연결 절차](../../STATE.md)

EKS 모듈 분리 이전 체크아웃을 갱신했다면 운영 루트에서 `terraform init`을 실행해 새 모듈 경로를 읽는다. `terraform state list module.eks`로 서울 운영 state에 기록된 EKS 주소를 확인할 수 있다. [운영 backend](backend.tf) · [이전 버전의 state 복구](../../STATE.md)

CloudFront 원본을 연결할 때는 서울 서비스 서브넷의 여유 IP, VPC Origin 할당량과 서비스 연결 역할 권한을 확인한다. DNS에는 이미 위임된 운영 영역을 사용한다. [도메인 import](imports.tf) · [ALB 인수 절차](SUBNET-RULES.md)

빌드 서버 추가와 피어링 복원 이전 배치도는 참고용으로 보존한다. 현재 라우팅은 서브넷 문서를 기준으로 확인한다. [이전 전체 배치도](../../../docs/architecture/awsdac/overview.png) · [이전 서울 서비스망](../../../docs/architecture/awsdac/seoul-network.png) · [현재 서브넷과 라우팅](SUBNET-RULES.md)
