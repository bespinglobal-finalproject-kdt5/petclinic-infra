# PetClinic 인프라

이 저장소는 PetClinic의 AWS 네트워크·배포 구성과 향후 Azure DR 구성을 관리한다. Angular WEB과 Spring REST API 소스는 [petclinic-eks-app](https://github.com/bespinglobal-finalproject-kdt5/petclinic-eks-app)에 있다. 인프라 PR 병합은 AWS 배포가 아니다. [팀 작업 절차](CONTRIBUTING.md) · [Terraform state 운영 기준](infra/STATE.md)

## 현재 배치 — 2026-11-23 KST 확인

| 위치 | 현재 구성 | 역할 |
|---|---|---|
| 서울 서비스 VPC 1 · `10.10.0.0/22` | 기존 서비스망·NAT와 오사카 관제망으로 가는 피어링 유지. Petclinic EKS·RDS는 롤백 상태 | 앱 워크로드용. Terraform에 배포 코드가 있다는 뜻과 지금 서비스가 실행 중이라는 뜻은 다르다. |
| 서울 관리 VPC 2 · `10.20.0.0/24` | 서울 2a 비공개 서브넷 `10.20.0.0/27` 하나. 전용 라우팅 테이블은 `local` 경로만 사용. 실행·중지된 EC2 없음 | 향후 SSM·`kubectl` 관리용 네트워크만 복원했다. **관리 서버도 빌드 서버도 현재 없다.** |
| 오사카 관제 VPC · `10.40.0.0/16` | 오사카 3b 서브넷 `10.40.0.0/27` 하나. `osaka-observe` EC2 실행 중, SSM `Online` | Grafana 등 관제용 호스트다. 서울 EKS 관리 서버나 CI 러너가 아니다. |

오사카 VPC·서브넷·EC2의 `Name`은 `osaka-observe`다. 자동 생성된 루트 EBS·기본 ENI·기본 라우팅 테이블·기본 SG·기본 NACL에도 `Name`을 지정했다. [관제망 접속과 역할 구분](infra/envs/aws-prod/OSAKA-VPC2.md). 운영 [Terraform state](infra/STATE.md)는 오사카 비공개 S3 버킷에 있으며, 이는 빌드 산출물 저장소가 아니다.

## 빌드 서버를 따로 둬야 하나?

**현재는 상시 빌드 EC2를 추가하지 않는다.** 관리와 빌드의 권한은 분리하되, 이를 위해 EC2 두 대를 운영할 필요는 없다.

| 작업 | 어디서 하는가 | 경계 |
|---|---|---|
| 앱 빌드·테스트 | 앱 저장소의 [GitHub Actions](https://github.com/bespinglobal-finalproject-kdt5/petclinic-eks-app/blob/main/.github/workflows/ubuntu-24.04.yml)가 `ubuntu-24.04` 러너에서 Angular와 Spring을 빌드하고 H2로 연동 검사 | 사설 EKS나 운영 DB 접속 불필요. 현재 이 워크플로는 AWS 인증, 이미지 push, 배포를 하지 않는다. |
| 인프라 검사 | 이 저장소의 [Terraform CI](.github/workflows/terraform-check.yml)가 PR에서 fmt·validate·mock 테스트 실행 | 운영 state에 연결하지 않고 `apply`하지 않는다. |
| 이미지 게시·운영 배포 | 재배포 시 [이미지 게시 스크립트](deploy/publish-release.sh)와 [Kubernetes 배포 절차](deploy/k8s/README.md)를 사용 | 이미지 게시를 자동화한다면 승인된 릴리스 작업에만 GitHub OIDC와 대상 ECR push 권한을 준다. 미래의 서울 관리 호스트는 SSM·`kubectl`용으로 두고 PR 빌드는 실행하지 않는다. |

**전용 러너가 필요한 경우:** 빌드가 사내 패키지 저장소 등 사설 자원에 반드시 접근해야 하거나 고정 송신 IP가 필요하면 VPC 연동 CodeBuild 또는 작업 종료 시 폐기하는 self-hosted runner를 검토한다. 그때도 관리 호스트·오사카 관제 VM과 실행 환경 및 IAM 역할을 분리한다. 현재 서울 VPC 2는 로컬 경로뿐이므로, 여기에 러너 EC2만 추가해도 GitHub·npm·Maven으로 나갈 수 없다. 사설 자원 접근이 필요하지 않다면 관리망에 인터넷 경로를 열기보다 기존 호스팅 러너를 쓰는 편이 단순하다.

## 왜 서비스 VPC는 `/22`인가?

두 가용 영역(AZ)에 앱 서브넷 `/24` 두 개와 퍼블릭·DB 서브넷 `/27` 네 개를 배치하면 총 640개 주소가 필요하다. `/23`은 512개라 부족하므로 현재 배치를 담는 최소 단일 대역은 `/22`(1,024개)다. 앱용 `/24`는 실측한 Pod 수가 아니라 확장 여유를 둔 설계값이다. [계층별 CIDR 선정 근거와 재검토 기준](infra/NETWORK.md#cidr-선정-근거)을 참고한다.

## 어디에서 무엇을 관리하나?

| 경로 | 역할 |
|---|---|
| `infra/modules/` | 재사용할 Terraform 자원 정의. 현재 공통 네트워크 모듈이 있다. |
| `infra/envs/aws-prod/` | 서울 서비스·관리망 및 오사카 관제망의 운영 루트. 전체 plan에는 롤백된 EKS·RDS·도메인 재생성이 포함될 수 있으므로 검토 없이 apply하지 않는다. |
| `infra/envs/azure-dr/` | Azure 복구 네트워크·VM·MySQL·Key Vault 구성 예정 위치. |
| `deploy/k8s/` | Angular WEB·Spring API의 EKS 배포 명세와 DB 초기화 절차. |
| `deploy/compose/` | Azure 복구 VM의 컨테이너 설정 예정 위치. |
| `deploy/monitoring/` | Prometheus·Grafana·수집 에이전트 설정 예정 위치. |

## 태그와 운영 기준

[공통 태그](infra/TAGS.md)는 `project=petclinic`, `environment=prod` 또는 `azure_dr`, `component` 세 가지다. 서비스·관리 VPC, 앱·DB 서브넷 등은 역할별 component를 쓰고, DNS·엣지는 `network`, state 버킷은 `management`를 쓴다. 기존 Route 53 영역은 import하므로 새 NS가 발급되지 않는다. 개별 DNS 레코드·라우팅 테이블 연결·ACM 검증 대기 리소스는 태그를 지원하지 않는다.

향후 EKS를 연결할 때는 기존 ALB를 중복 생성하지 않는다. 모니터링 수집 방식과 Azure DR 전환 승인·검증 순서는 별도 PR에서 확정한다.
