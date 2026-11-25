# PetClinic 운영 토폴로지

2026년 11월 25일 KST에 운영 AWS, Kubernetes의 `petclinic` 네임스페이스, 인프라 `main`의 `e6cb3dc`를 대조했다. Pod 수와 배치, RDS 주·대기 AZ는 관측 시점의 값이다. [한 장 PNG](production-topology.drawio.png) · [편집용 draw.io](production-topology.drawio)

## 사용자 요청과 데이터

1. 인터넷 공개 ALB의 유일한 리스너는 HTTP 80이다. Kubernetes Gateway `petclinic-public`과 같은 이름의 HTTPRoute가 요청을 분기한다. Route 53 도메인은 별도의 비활성 CloudFront 배포를 가리키며, 서울 ACM 인증서는 발급 상태이고 ALB에 연결된 HTTPS 리스너는 없다. [엣지 설정](../../infra/envs/aws-prod/edge/)
2. `/petclinic/api`와 `/petclinic/api/*`는 `rest` Service(9966)가 가리키는 2a REST Pod 한 개로, 나머지 `/*`는 `web` Service(80)가 가리키는 2c 웹 Pod 두 개로 전달된다. ALB는 IP 유형 대상 그룹을 사용한다. 실제 대상 포트는 각각 9966과 8080이며 세 대상 모두 정상이다. [앱 소스](https://github.com/bespinglobal-finalproject-kdt5/petclinic-eks-app)
3. REST Pod의 JDBC 로그에서 운영 RDS 호스트를 확인했고, 같은 Pod에서 해당 호스트가 해석된 IP의 5432 포트로 열린 TCP 연결도 확인했다. RDS는 두 DB 전용 서브넷의 Multi-AZ 인스턴스다. 주 DB와 대기 DB는 서울 리전 안에서 동기 복제한다. [EKS → RDS 보안 그룹](../../infra/envs/aws-prod/eks-cluster.tf) · [RDS 구성](../../infra/envs/aws-prod/seoul-vpc1-service/rds-database.tf)

## 운영·관리 경로

| 출발지와 목적지 | 연결 근거 |
|---|---|
| 관리 EC2 → EKS | 프라이빗 관리 서브넷의 `10.10.0.0/22` 경로와 서비스 앱 서브넷의 `10.20.0.0/24` 경로가 서울 VPC 피어링을 사용한다. EKS 프라이빗 API는 관리 서버에서 오는 TCP 443을 허용한다. |
| 관리 EC2 → RDS | 관리 서버는 두 DB 서브넷을 포함하는 `10.10.2.64/26`으로 TCP 5432를 송신한다. RDS는 관리 서버 `10.20.0.18/32`에서 수신하고, 두 DB 서브넷의 공통 라우팅 테이블은 같은 `/32`로 응답을 피어링에 보낸다. 관리 EC2에서 PostgreSQL SSL 협상 응답을 확인했다. |
| 빌드 EC2 → RDS | RDS에는 빌드 사설 IP `10.20.0.58/32` 수신 규칙이 있다. 빌드 서버 송신은 TCP 80·443이고 빌드 서브넷에는 서비스망 피어링 경로가 없다. |
| 운영 접속과 송신 | 관리 서브넷은 SSM·SSM Messages 인터페이스 엔드포인트와 관리 NAT를 사용한다. 관리 VPC의 빌드 EC2는 퍼블릭 서브넷에서 EIP를 사용한다. 서비스 쪽 프라이빗 앱 서브넷 두 개는 2a의 서비스 NAT를 공유한다. |

[서울 피어링 및 관리 보안 규칙](../../infra/envs/aws-prod/eks-management-network.tf) · [DB 반환 경로](../../infra/envs/aws-prod/seoul-vpc1-service/main.tf) · [빌드 서버](../../infra/envs/aws-prod/seoul-vpc2-management/build-server/)

## 운영 상태 저장과 DR

오사카의 버전 관리가 켜진 S3 버킷에 Terraform 운영 state를 보관하고 S3 잠금 파일을 사용한다. Azure DR의 `10.30.0.0/24`는 예약 대역이다. 현 운영 RDS의 자동 백업 보존 기간은 0일이며 `rds.logical_replication=0`이다. DB 서브넷의 경로는 서비스 VPC 내부와 서울 관리 EC2 한 대를 대상으로 한다. [S3 backend](../../infra/envs/aws-prod/backend.tf) · [Azure DR 구현 범위](../../infra/envs/azure-dr/README.md)
