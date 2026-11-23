# PetClinic 인프라

이 저장소는 PetClinic의 AWS 네트워크·배포 구성과 향후 Azure DR 구성을 관리한다. Angular WEB과 Spring REST API 소스는 [petclinic-eks-app](https://github.com/bespinglobal-finalproject-kdt5/petclinic-eks-app)에 있다. 인프라 PR 병합은 AWS 배포가 아니다. [팀 작업 절차](CONTRIBUTING.md) · [Terraform state 운영 기준](infra/STATE.md)

## 현재 배치 — 2026-11-23 KST 확인

| 위치 | 현재 구성 | 역할 |
|---|---|---|
| 서울 서비스 VPC 1 · `10.10.0.0/22` | 서비스망과 NAT를 운영한다. Petclinic EKS·RDS는 롤백 상태 | 앱 워크로드용. Terraform에 배포 코드가 있다는 뜻과 지금 서비스가 실행 중이라는 뜻은 다르다. |
| 서울 관리 VPC 2 · `10.20.0.0/24` | 서울 2a 프라이빗 `10.20.0.0/27`은 VPC 로컬 경로를 사용한다. 퍼블릭 `10.20.0.32/27`은 전용 IGW로 송신한다. | 퍼블릭 서브넷에 Ubuntu 빌드용 EC2 한 대를 둔다. 프라이빗 관리 EC2는 운영 plan 검증까지 완료한 배포 대기 구성이다. |
| 오사카 관제 VPC · `10.40.0.0/16` | 오사카 3b 서브넷 `10.40.0.0/27` 하나와 SSM용 IAM 역할·정책·인스턴스 프로필 | 향후 관제용으로 보존한다. 실행할 EC2와 SSM 세션 대상은 없다. |

오사카 VPC·서브넷의 `Name`은 `osaka-observe`다. 관제 서브넷의 전용 라우팅 테이블은 서울 VPC 1의 두 앱 서브넷으로 가는 트래픽을 리전 간 피어링으로 보낸다. [오사카 보존 자원](infra/envs/aws-prod/OSAKA-VPC2.md). 운영 [Terraform state](infra/STATE.md)는 오사카 비공개 S3 버킷에 있으며, 이는 빌드 산출물 저장소가 아니다.

## 서울 EKS 관리 경로

서울 VPC 2의 프라이빗 서브넷에 Ubuntu 관리 EC2와 SSM 인터페이스 엔드포인트 두 개를 정의했다. 적용 후에는 `management_instance_id`로 Session Manager에 접속한다. [관리 서버 사양과 접속 명령](infra/envs/aws-prod/seoul-vpc2-management/README.md)

VPC 1의 비공개 EKS API를 운영하려면 VPC 2에서 API까지의 왕복 경로와 DNS, 보안 그룹의 TCP 443 허용, EKS Access Entry 등 클러스터 권한을 별도로 구성해야 한다.

## 서울 빌드 서버

`petclinic-prod-build-server`는 Ubuntu 24.04 LTS x86_64, 온디맨드 `m7i.large`(2 vCPU, 8 GiB), 암호화 gp3 50 GiB를 사용한다. 기본 Ubuntu 이미지로 시작하며 SSM Session Manager로 접속한다. 빌드 도구는 운영자가 필요할 때 설치한다. 접속 명령과 출력값은 [AWS 운영 환경](infra/envs/aws-prod/README.md#서울-빌드-서버)에 있다.

빌드 서버의 인스턴스 역할은 SSM용이다. 앱 저장소는 [GitHub Actions](https://github.com/bespinglobal-finalproject-kdt5/petclinic-eks-app/blob/main/.github/workflows/ubuntu-24.04.yml)에서 PR을 검사하고, 인프라 저장소는 [Terraform CI](.github/workflows/terraform-check.yml)에서 검사한다.

## 왜 서비스 VPC는 `/22`인가?

두 가용 영역(AZ)에 앱 서브넷 `/24` 두 개와 퍼블릭·DB 서브넷 `/27` 네 개를 배치하면 총 640개 주소가 필요하다. `/23`은 512개라 부족하므로 현재 배치를 담는 최소 단일 대역은 `/22`(1,024개)다. 앱용 `/24`는 실측한 Pod 수가 아니라 확장 여유를 둔 설계값이다. [계층별 CIDR 선정 근거와 재검토 기준](infra/NETWORK.md#cidr-선정-근거)을 참고한다.

## 추후 설계안 (미구현)

- [정적 웹·감사 로그·앱 로그의 S3 분리](docs/architecture/planned-s3-storage.md): 서울 CloudFront 정적 원본, 오사카 EC2 감사 로그, 선택적 Loki 장기 보관. 현재 운영 리소스 목록이 아니다.

## 어디에서 무엇을 관리하나?

| 경로 | 역할 |
|---|---|
| [infra/envs/aws-prod/](infra/envs/aws-prod/README.md) | 서울 네트워크·서비스 진입점과 오사카 관제망을 관리한다. EKS·RDS 담당자에게 VPC·서브넷 ID를 제공하고, EKS 담당자가 전달한 ALB ARN을 CloudFront에 연결한다. |
| [infra/envs/azure-dr/](infra/envs/azure-dr/README.md) | Azure 복구 네트워크·VM·MySQL·Key Vault 구성 예정 위치. |

## 태그와 운영 기준

[공통 태그](infra/TAGS.md)는 `project=petclinic`, `environment=prod` 또는 `azure_dr`, `component` 세 가지다. 서비스·관리 VPC, 앱·DB 서브넷 등은 역할별 component를 쓰고, DNS·엣지는 `network`, state 버킷은 `management`를 쓴다. 기존 Route 53 영역은 import하므로 새 NS가 발급되지 않는다. 개별 DNS 레코드·라우팅 테이블 연결·ACM 검증 대기 리소스는 태그를 지원하지 않는다.

서울 내부 ALB와 보안 그룹·대상 그룹은 EKS Ingress 담당자가 관리한다. 운영 루트는 `eks_alb_arn`을 받으면 CloudFront를 활성화한다. 모니터링 수집 방식과 Azure DR 전환 승인·검증 순서는 별도 PR에서 확정한다.
