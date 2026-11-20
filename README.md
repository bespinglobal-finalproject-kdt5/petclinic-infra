# PetClinic 인프라

이 저장소는 AWS 운영망과 Azure 재해복구 환경의 인프라·배포 설정을 관리한다. Angular WEB과 Spring REST API 소스는 별도 비공개 `petclinic-dev` 저장소에서 관리한다. 처음 참여한다면 [작업 브랜치·PR 안내](CONTRIBUTING.md), 배포 담당자는 [공유 state 절차](infra/STATE.md)를 확인한다. 병합은 AWS 배포가 아니다.

## 구성과 배포 범위

- **서울:** 서비스 VPC `10.10.0.0/22`와 관리 VPC `10.20.0.0/24`는 `aws-network` 모듈 한 번의 호출로 구성한다. 앱 서브넷 두 곳은 `2a`의 NAT Gateway 하나를 공유한다. DB·관리 서브넷에는 인터넷 기본 경로가 없다.
- **도메인 진입점:** Terraform이 프라이빗 앱 서브넷 두 곳에 내부 ALB를 관리한다. VPC 오리진은 이 ALB를 대상으로 하며 `/health`는 고정 200이다. [PR #10](https://github.com/bespinglobal-finalproject-kdt5/petclinic-infra/pull/10) 이후 state 복구 시점에는 CloudFront 배포와 도메인 A·AAAA 별칭은 코드에만 있었으며 태그 작업에서는 생성하지 않는다. EKS나 앱 준비 상태를 검증하는 엔드포인트가 아니다.
- **도쿄:** 비공개 S3 버킷은 운영 Terraform state를 보관하는 별도 기반이다. Azure DR state는 AWS와 분리한다.

## 왜 서비스 VPC는 `/22`인가?

두 가용 영역(AZ)에 앱 서브넷 `/24` 두 개와 퍼블릭·DB 서브넷 `/27` 네 개를 배치하면 총 640개 주소가 필요하다. `/23`은 512개라 부족하므로 현재 배치를 담는 최소 단일 대역은 `/22`(1,024개)다. 앱용 `/24`는 실측한 Pod 수가 아니라 확장 여유를 둔 설계값이다. [계층별 CIDR 선정 근거와 재검토 기준](infra/NETWORK.md#cidr-선정-근거)을 참고한다.

## 어디에서 무엇을 관리하나?

| 경로 | 역할 |
|---|---|
| `infra/modules/` | 재사용할 Terraform 자원 정의. 현재 공통 네트워크 모듈이 있다. |
| `infra/envs/aws-prod/` | 서울 네트워크·내부 ALB, CloudFront·인증서·DNS를 조합하는 운영 실행 위치. EKS·RDS·관리 EC2는 후속 범위다. |
| `infra/envs/azure-dr/` | Azure 복구 네트워크·VM·MySQL·Key Vault 구성 예정 위치. |
| `deploy/k8s/` | Angular WEB·Spring API의 EKS 배포 명세 예정 위치. |
| `deploy/compose/` | Azure 복구 VM의 컨테이너 설정 예정 위치. |
| `deploy/monitoring/` | Prometheus·Grafana·수집 에이전트 설정 예정 위치. |

## 태그와 운영 기준

[공통 태그](infra/TAGS.md)는 `project=petclinic`, `environment=prod` 또는 `azure_dr`, `component` 세 가지다. 서비스·관리 VPC, 앱·DB 서브넷 등은 역할별 component를 쓰고, DNS·엣지는 `network`, state 버킷은 `management`를 쓴다. 기존 Route 53 영역은 import하므로 새 NS가 발급되지 않는다. 개별 DNS 레코드·라우팅 테이블 연결·ACM 검증 대기 리소스는 태그를 지원하지 않는다.

향후 EKS를 연결할 때는 기존 ALB를 중복 생성하지 않는다. 모니터링 수집 방식과 Azure DR 전환 승인·검증 순서는 별도 PR에서 확정한다.
