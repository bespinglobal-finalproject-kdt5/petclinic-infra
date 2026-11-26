# AWS 운영 환경

`infra/envs/aws-prod/`는 서울 리소스 및 글로벌 서비스를 함께 관리하는 Terraform 루트다. 운영 state는 서울 S3 버킷 `petclinic-prod-tfstate-seoul`의 `petclinic/aws-prod/terraform.tfstate`에 저장하며 S3 잠금 파일을 사용한다. [루트 모듈 연결](main.tf) · [backend 설정](backend.tf) · [state 접근과 복구](../../STATE.md)

## 모듈 구성

운영 루트에서 사용하는 Route 53 공개 호스팅 영역과 CloudFront 원본 연결용 IP 대역 목록은 `data.tf`에서 조회한다. 기존 호스팅 영역을 인수하는 선언은 `imports.tf`, 팀에서 조회할 출력은 `outputs.tf`에 둔다. [외부 리소스 조회](data.tf) · [영역 import](imports.tf) · [루트 출력](outputs.tf)

| 하위 모듈 | 관리하는 자원 |
|---|---|
| [seoul_vpc1](seoul-vpc1-service/main.tf) | 서울 서비스 VPC, 앱·DB·퍼블릭 서브넷 각 2개, IGW·NAT, 피어링 반환 경로, [Multi-AZ RDS PostgreSQL](seoul-vpc1-service/rds-database.tf) |
| [seoul_vpc2](seoul-vpc2-management/main.tf) | 서울 관리 VPC와 두 서브넷, 관리 IGW·NAT, 빌드·관리 EC2, SSM 엔드포인트. [EC2 모듈 연결](seoul-vpc2-management/servers.tf) |
| [eks](eks/cluster.tf) | 비공개 EKS 클러스터, 관리형 노드 그룹, EKS 애드온, 관리자 접근 권한, 컨트롤러 IAM 역할 |
| [cloudfront](cloudfront/cloudfront.tf) | Route 53, CloudFront용 미국 동부 ACM 인증서, ALB용 서울 ACM 인증서, CloudFront 배포 및 선택적 VPC Origin |

운영 state에서 EKS 리소스는 `module.eks` 아래에 있다. CloudFront 코드는 `cloudfront/`에 있다. 루트의 `moved` 블록은 기존 `module.edge` 주소를 `module.cloudfront`에 연결하며, 운영 state는 이 변경을 적용할 때 갱신된다. [루트 모듈 선언](main.tf)

루트는 관리 EC2에서 피어링을 거쳐 EKS API(TCP 443)와 RDS(TCP 5432)로 가는 규칙을 연결한다. 같은 서비스 VPC 안에서 RDS로 접속하는 EKS 워크로드에는 EKS 클러스터 보안 그룹을 출발지로 허용한다. [모듈 간 보안 그룹 규칙](network-connections.tf) · [관리 역할의 EKS 권한](management-access.tf) · [서브넷별 경로](SUBNET-RULES.md)

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
| `eks_alb_arn` | CloudFront VPC Origin 활성화 입력. EKS 담당자가 생성한 내부 ALB와 정상 앱 타깃을 확인할 때까지 기본값 `null`을 사용한다. |

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

2026년 11월 25일 확인된 앱 경로는 공개 ALB(HTTP 80) → EKS Gateway의 경로 규칙 → 웹·REST Pod였다. 아래 내부 ALB와 VPC Origin은 향후 CloudFront를 활성화할 때 사용할 경로다. [운영 확인 기록](../../../docs/architecture/production-topology.md)

두 리전의 ACM 인증서와 공통 DNS 검증 CNAME에는 `prevent_destroy`를 설정했다. 이 리소스의 삭제나 교체가 포함되면 Terraform은 전체 계획을 거부한다. [인증서 삭제 보호](cloudfront/acm.tf)

`mission-critical.site`의 기존 퍼블릭 호스팅 영역을 import하고 A·AAAA 별칭을 CloudFront로 연결한다. DNS 검증 CNAME과 `us-east-1`의 ACM 인증서를 관리한다. 기본값 `eks_alb_arn = null`에서는 CloudFront가 비활성이고 VPC Origin이 없다. 배포 구성의 임시 원본 이름은 `origin-pending.mission-critical.site`이며 해당 이름에 DNS 레코드는 생성하지 않는다. [영역 import](imports.tf) · [Route 53](cloudfront/dns.tf) · [ACM과 DNS 검증](cloudfront/acm.tf) · [CloudFront 배포](cloudfront/cloudfront.tf) · [EKS ALB와 VPC Origin](cloudfront/vpc-origin.tf)

EKS 담당자가 AWS Load Balancer Controller를 통해 두 프라이빗 앱 서브넷에 내부 ALB를 생성하고 앱 타깃을 연결한다. 서울 ACM 인증서와 DNS 검증 CNAME은 이 Terraform 구성이 관리한다. 443 리스너에 사용할 인증서 ARN은 `terraform -chdir=infra/envs/aws-prod output -raw seoul_alb_certificate_arn`으로 조회한다. [인증서](cloudfront/acm.tf) · [운영 출력](outputs.tf)

CloudFront 활성화 전에는 새 ALB의 HTTPS 443 리스너, 앱 대상 그룹의 정상 타깃과 앱 응답을 확인한다. 현재 VPC Origin 정책은 `http-only`다. 443으로 전환할 때는 `https-only` 정책과 인증서가 유효한 오리진 호스트 이름을 구성한 뒤 `eks_alb_arn`을 지정한다. [VPC Origin 정책](cloudfront/vpc-origin.tf)

EKS 모듈은 AL2023 x86_64 관리형 노드 그룹, EKS 애드온 4개, AWS Load Balancer Controller와 Cluster Autoscaler용 IAM 역할을 관리한다. Angular와 Spring REST 소스는 팀의 애플리케이션 저장소에 있다. [노드 그룹](eks/nodes.tf) · [애드온](eks/addons.tf) · [컨트롤러 IAM](eks/controllers.tf) · [애플리케이션 소스](https://github.com/bespinglobal-finalproject-kdt5/petclinic-eks-app)

## 서울 빌드·관리 서버

퍼블릭 빌드 EC2에는 EIP를 연결한다. 프라이빗 관리 EC2는 SSM 엔드포인트로 운영 세션을 열고, 서비스 VPC 피어링으로 EKS API와 PostgreSQL에 접근한다. [서버별 사양·보안 그룹·SSM 접속 명령](seoul-vpc2-management/README.md)

## 검증과 배포

PR을 열면 Terraform 1.12.2로 `fmt`, `init -backend=false`, `validate`, AWS mock 테스트를 실행한다. 실제 운영 plan은 승인된 AWS 프로필로 S3 backend를 초기화한 디렉터리에서 실행한다. 배포 담당자는 계획의 생성·변경·삭제 대상을 확인한 후 저장한 plan을 적용한다. [CI 정의](../../../.github/workflows/terraform-check.yml) · [운영 backend 연결 절차](../../STATE.md)

EKS 모듈 분리 이전 체크아웃을 갱신했다면 운영 루트에서 `terraform init`을 실행해 새 모듈 경로를 읽는다. `terraform state list module.eks`로 서울 운영 state에 기록된 EKS 주소를 확인할 수 있다. [운영 backend](backend.tf) · [이전 버전의 state 복구](../../STATE.md)

CloudFront 원본을 연결할 때는 서울 서비스 서브넷의 여유 IP, VPC Origin 할당량과 서비스 연결 역할 권한을 확인한다. DNS에는 이미 위임된 운영 영역을 사용한다. [도메인 import](imports.tf) · [ALB 인수 절차](SUBNET-RULES.md)

빌드 서버 추가와 피어링 복원 이전 배치도는 참고용으로 보존한다. 현재 라우팅은 서브넷 문서를 기준으로 확인한다. [이전 전체 배치도](../../../docs/architecture/awsdac/overview.png) · [이전 서울 서비스망](../../../docs/architecture/awsdac/seoul-network.png) · [현재 서브넷과 라우팅](SUBNET-RULES.md)
