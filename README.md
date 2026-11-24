# PetClinic 인프라

PetClinic의 Terraform 실행 루트는 `infra/envs/aws-prod/`다. 서울 서비스망과 관리망, `mission-critical.site`의 DNS·인증서·CloudFront를 관리한다. Angular WEB과 Spring REST 소스는 앱 저장소에 있다. [AWS 운영 가이드](infra/envs/aws-prod/README.md) · [애플리케이션 저장소](https://github.com/bespinglobal-finalproject-kdt5/petclinic-eks-app)

## 운영 현황

2026-11-23 KST 기준이다. PR 병합 시 GitHub Actions가 검증한 코드가 `main`에 반영되고, AWS 변경은 운영 담당자가 별도로 `terraform apply`할 때 반영된다.

| 구성 | 운영 상태 |
|---|---|
| 서울 VPC 1 · 서비스 | `10.10.0.0/22`에 앱·퍼블릭·DB 서브넷을 두 AZ에 배치했다. 두 앱 서브넷은 서울 2a의 NAT 하나를 공유한다. EKS와 RDS 생성은 별도 담당 범위다. |
| 서울 VPC 2 · 관리 | `10.20.0.0/24`의 퍼블릭 서브넷에서 빌드 EC2가 실행 중이다. 프라이빗 관리 EC2도 실행 중이며, 두 서버 모두 SSM에 온라인으로 등록돼 있다. 관리 서브넷의 SSM 엔드포인트 2개는 사용 가능하다. |
| 서비스 도메인 | Route 53 별칭과 CloudFront 배포, 미국 동부 버지니아 북부(`us-east-1`) ACM 인증서를 유지한다. CloudFront는 EKS의 내부 ALB 연결을 기다리는 비활성 상태다. |
| Azure DR | `10.30.0.0/24` 주소를 예약했다. Azure 리소스와 backend 구현은 계획 단계다. |

## 서울 서비스망과 관리망의 연결

서울 서비스 VPC의 두 앱 서브넷은 관리 VPC 대역 `10.20.0.0/24`로 가는 피어링 경로를 공유한다. 관리 VPC의 프라이빗 서브넷은 서비스 VPC 대역 `10.10.0.0/22`로 돌아오는 경로를 사용한다. [서울 앱 라우팅](infra/envs/aws-prod/seoul-vpc1-service/main.tf) · [서울 VPC 피어링](infra/envs/aws-prod/eks-management-network.tf)

## 작업별 문서

EKS·DB 담당자는 서울 VPC 1의 서브넷 ID를 운영 루트 출력에서 받는다. 공통 태그는 `project=petclinic`, 환경별 `environment`, 역할별 `component`이며 서브넷 이름은 `Name` 태그로 확인한다.

| 작업 | 문서 |
|---|---|
| AWS 모듈 찾기, EKS·DB 담당자에게 서브넷 전달, CloudFront 연결 | [AWS 운영 가이드](infra/envs/aws-prod/README.md) |
| 빌드 서버 또는 관리 서버에 SSM으로 접속 | [서울 VPC 2 서버 및 접속 명령](infra/envs/aws-prod/seoul-vpc2-management/README.md) |
| CIDR·라우팅·태그 확인 | [서브넷과 EKS 연결 규칙](infra/envs/aws-prod/SUBNET-RULES.md) · [서비스 VPC를 /22로 정한 근거](infra/NETWORK.md#cidr-선정-근거) · [공통 태그](infra/TAGS.md) |
| 로컬 검사, PR, 운영 state 처리 | [팀 작업 절차](CONTRIBUTING.md) · [Terraform CI](.github/workflows/terraform-check.yml) · [공유 state 운영 기준](infra/STATE.md) |
| 후속 설계 확인 | [Azure DR 예약 대역](infra/envs/azure-dr/README.md) · [정적 웹·로그용 S3 설계안](docs/architecture/planned-s3-storage.md) |
