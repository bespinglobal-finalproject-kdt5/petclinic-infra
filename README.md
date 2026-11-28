# PetClinic 인프라

PetClinic은 AWS 서울 리전의 EKS에서 Angular 웹과 Spring REST API를 실행하고, 진료 데이터를 RDS PostgreSQL에 저장한다. 이 저장소의 Terraform 실행 루트는 `infra/envs/aws-prod/`다. [AWS 운영 가이드](infra/envs/aws-prod/README.md) · [애플리케이션 저장소](https://github.com/bespinglobal-finalproject-kdt5/petclinic-eks-app)

## 운영 토폴로지

2026년 11월 28일 AWS CLI 조회 기준이다. 공개 ALB에서 앱 타깃까지의 상태, RDS 구성, CloudFront 원본 연결 상태를 확인했다.

| 구성 | 운영 상태 |
|---|---|
| 앱 진입점 | 공개 ALB에서 HTTP 80을, 내부 ALB에서 HTTPS 443을 수신한다. 두 ALB 각각 웹·REST 대상 그룹 2개에 정상 IP 타깃이 2개씩 있다. |
| 서울 서비스 VPC · `10.10.0.0/22` | 2a·2c에 퍼블릭·앱·DB 서브넷을 배치했다. 프라이빗 EKS 1.36의 `t3.medium` 워커는 AZ마다 한 대이며, 앱 서브넷은 2a NAT를 공유한다. |
| RDS · `petclinic-db` | PostgreSQL 16.13 Multi-AZ로, 주 DB는 2c, 대기는 2a다. 공개 접근 플래그는 켜져 있다. DB 서브넷의 라우팅 테이블에는 VPC 로컬 경로와 관리 EC2로 가는 피어링 경로가 있다. 조회 당시 RDS 자동 백업 보존 기간은 0일이다. |
| Azure DR의 DB 접근 경로 | Azure NAT의 고정 IPv4에서 공개 `AWS-Azure` NLB의 TCP 5432로 접근한다. NLB는 RDS 주 인스턴스의 사설 IP 하나를 타깃으로 사용한다. 타깃 상태는 `healthy`이며, 이 조회에서 Azure 구독의 복제 상태는 검증하지 않았다. [NLB와 보안 그룹](infra/envs/aws-prod/seoul-vpc1-service/azure-dr-nlb.tf) |
| 서울 관리 VPC · `10.20.0.0/24` | 빌드 EC2와 관리 EC2가 실행 중이며 둘 다 SSM에 온라인으로 등록돼 있다. 관리 EC2는 피어링으로 EKS API(443)와 RDS(5432)에 접근한다. |
| DNS·CloudFront | `mission-critical.site`의 A·AAAA 별칭은 비활성 CloudFront 배포를 가리킨다. 내부 ALB용 HTTPS VPC Origin은 배포됐고, 배포의 원본은 아직 `origin-pending.mission-critical.site`다. [CloudFront 전환 절차](infra/envs/aws-prod/README.md#서비스-진입점과-cloudfront-전환) |
| Terraform state | AWS 운영 state는 서울 S3에, Azure DR state는 Korea Central의 전용 Blob 컨테이너에 저장한다. |

11월 25일에 관측한 워크로드 배치와 요청 경로는 당시 도면에 남아 있다. [이전 운영 배치도](docs/architecture/production-topology.drawio.png) · [당시 관측 기록](docs/architecture/production-topology.md)

## Terraform 코드 위치

서울의 두 VPC, EKS, CloudFront는 하나의 운영 루트에서 연결한다. 모듈을 수정할 때도 `terraform plan`은 `infra/envs/aws-prod/`에서 실행한다. [모듈 연결](infra/envs/aws-prod/main.tf) · [서울 S3 backend](infra/envs/aws-prod/backend.tf)

| 변경할 대상 | 코드 위치 |
|---|---|
| 서비스 VPC·서브넷·NAT, RDS PostgreSQL | [seoul-vpc1-service/](infra/envs/aws-prod/seoul-vpc1-service/) |
| 관리 VPC, 빌드·관리 EC2와 SSM | [seoul-vpc2-management/](infra/envs/aws-prod/seoul-vpc2-management/) |
| EKS 클러스터·노드·애드온, 컨트롤러 IAM | [eks/](infra/envs/aws-prod/eks/) |
| CloudFront 배포·VPC Origin, Route 53·ACM (`module.cloudfront`) | [cloudfront/](infra/envs/aws-prod/cloudfront/) |
| VPC 피어링, 관리 EC2 → EKS·RDS, EKS → RDS 보안 그룹 규칙 | [connectivity/](infra/envs/aws-prod/connectivity/) |

## 작업별 문서

GitHub Actions는 `main` 대상 PR에서 Terraform 포맷·유효성·mock 테스트를 검사한다. 운영 담당자는 병합된 `main`에서 검토한 plan을 적용한다. 서브넷 ID는 운영 루트 출력에서, 리소스 역할은 `project`·`environment`·`component` 태그에서 확인한다.

| 작업 | 문서 |
|---|---|
| AWS 모듈 찾기, EKS·DB 담당자에게 서브넷 전달, CloudFront 연결 | [AWS 운영 가이드](infra/envs/aws-prod/README.md) |
| 빌드 서버 또는 관리 서버에 SSM으로 접속 | [서울 VPC 2 서버 및 접속 명령](infra/envs/aws-prod/seoul-vpc2-management/README.md) |
| CIDR·라우팅·태그 확인 | [서브넷과 EKS 연결 규칙](infra/envs/aws-prod/SUBNET-RULES.md) · [서비스 VPC를 /22로 정한 근거](infra/NETWORK.md#cidr-선정-근거) · [공통 태그](infra/TAGS.md) |
| 로컬 검사, PR, 운영 state 처리 | [팀 작업 절차](CONTRIBUTING.md) · [Terraform CI](.github/workflows/terraform-check.yml) · [공유 state 운영 기준](infra/STATE.md) |
| Azure DR 및 후속 설계 | [Azure DR PoC와 팀 접근](infra/envs/azure-dr/README.md) · [정적 웹·로그용 S3 설계안](docs/architecture/planned-s3-storage.md) |
