# PetClinic 앱 소스와 인프라

`feat/petclinic-app-sources`는 배포 구성 `1868d95` 위에 Angular와 Spring REST 소스를 함께 둔 브랜치다. [WEB](spring-petclinic-angular/README.md), [WAS](spring-petclinic-rest/readme.md), [AWS Terraform](infra/envs/aws-prod/), [Kubernetes 배포 절차](deploy/k8s/README.md)를 참조한다. 이 브랜치를 푸시하는 것만으로는 AWS가 변경되지 않는다.

로컬 실행은 별도 터미널에서 `(cd spring-petclinic-rest && ./mvnw spring-boot:run)`(JDK 21)과 `(cd spring-petclinic-angular && npm ci && npm start)`(Node.js 24)를 실행하고 `http://localhost:4200/`을 연다. 운영 초기화 절차에서 이 체크아웃의 SQL을 사용할 경우 저장소 루트에서 `export SCHEMA_SQL="$PWD/spring-petclinic-rest/src/main/resources/db/postgres/schema.sql"`을 먼저 실행한다.

## 구성과 배포 범위

- **서울:** 서비스 VPC `10.10.0.0/22`와 관리 VPC `10.20.0.0/24`는 `aws-network` 모듈 한 번의 호출로 구성한다. 앱 서브넷 두 곳은 `2a`의 NAT Gateway 하나를 공유한다. DB·관리 서브넷에는 인터넷 기본 경로가 없다.
- **도메인 진입점:** CloudFront VPC Origin이 기존 내부 ALB에 연결된다. `/health`는 고정 200이고 앱·DB 상태 검사가 아니다. ALB는 `/petclinic/api/*`를 WAS로, 화면 요청을 WEB으로 전달한다.
- **도쿄:** 비공개 S3 버킷은 운영 Terraform state를 보관하는 별도 기반이다. Azure DR state는 AWS와 분리한다.

## 왜 서비스 VPC는 `/22`인가?

두 가용 영역(AZ)에 앱 서브넷 `/24` 두 개와 퍼블릭·DB 서브넷 `/27` 네 개를 배치하면 총 640개 주소가 필요하다. `/23`은 512개라 부족하므로 현재 배치를 담는 최소 단일 대역은 `/22`(1,024개)다. 앱용 `/24`는 실측한 Pod 수가 아니라 확장 여유를 둔 설계값이다. [계층별 CIDR 선정 근거와 재검토 기준](infra/NETWORK.md#cidr-선정-근거)을 참고한다.

## 어디에서 무엇을 관리하나?

| 경로 | 역할 |
|---|---|
| `infra/modules/` | 재사용할 Terraform 자원 정의. 현재 공통 네트워크 모듈이 있다. |
| `infra/envs/aws-prod/` | 서울 네트워크, EKS, RDS PostgreSQL Multi-AZ, 관리 EC2, ALB, CloudFront·인증서·DNS의 운영 Terraform. |
| `infra/envs/azure-dr/` | Azure 복구 네트워크·VM·MySQL·Key Vault 구성 예정 위치. |
| `deploy/k8s/` | Angular WEB·Spring API의 배포 명세와 DB 초기화 절차. |
| `deploy/compose/` | Azure 복구 VM의 컨테이너 설정 예정 위치. |
| `deploy/monitoring/` | Prometheus·Grafana·수집 에이전트 설정 예정 위치. |

## 태그와 운영 기준

[공통 태그](infra/TAGS.md)는 `project=petclinic`, `environment=prod` 또는 `azure_dr`, `component` 세 가지다. 서비스·관리 VPC, 앱·DB 서브넷 등은 역할별 component를 쓰고, DNS·엣지는 `network`, state 버킷은 `management`를 쓴다. 기존 Route 53 영역은 import하므로 새 NS가 발급되지 않는다. 개별 DNS 레코드·라우팅 테이블 연결·ACM 검증 대기 리소스는 태그를 지원하지 않는다.

운영 state는 하나만 사용한다. 앱 소스 이전을 위해 추가 `terraform apply`를 실행할 필요가 없다.
