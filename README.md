# PetClinic 인프라 구조 초안

처음 참여한다면 [팀원 clone·코드 작성·PR 안내](CONTRIBUTING.md)를 먼저 읽어주세요. 모듈 담당자는 [공통 네트워크](infra/NETWORK.md), 배포 담당자는 [공유 state 설정](infra/STATE.md)을 확인하세요.

## 왜 서비스 VPC는 `/22`인가?

두 가용 영역(AZ)에 앱 서브넷 `/24` 두 개와 ALB·DB 서브넷 `/27` 네 개를 배치하면 총 640개 주소가 필요하다. `/23`은 512개라 부족하므로 현재 배치를 담는 최소 단일 대역은 `/22`(1,024개)다. 앱용 `/24`는 실측한 Pod 수가 아니라 확장 여유를 둔 설계값이다. [계층별 CIDR 선정 근거와 재검토 기준](infra/NETWORK.md#cidr-선정-근거)을 참고한다.

## 어디에서 무엇을 관리하나?

| 경로 | 역할 |
|---|---|
| infra/modules/ | Terraform으로 재사용할 클라우드 자원을 정의한다. |
| infra/envs/aws-prod/ | AWS 운영 환경을 구성한다. 서비스 VPC에는 EKS와 RDS를, 관리 VPC에는 kubectl용 EC2를 둔다. |
| infra/envs/azure-dr/ | Azure 복구 환경의 네트워크, VM, MySQL, Key Vault를 구성한다. AWS와 Terraform 상태를 분리한다. |
| deploy/k8s/ | AWS EKS에서 실행할 React WEB과 Spring API의 배포 설정을 관리한다. |
| deploy/compose/ | Azure 복구 VM에서 실행할 컨테이너 구성을 관리한다. |
| deploy/monitoring/ | Prometheus, Grafana, 수집 에이전트 설정을 관리한다. |

서비스 VPC와 관리 VPC는 같은 aws-network 모듈을 두 번 사용하되, 서브넷과 라우팅은 각 용도에 맞춘다.

## 팀 리뷰에서 결정할 사항

- ALB: Terraform과 중복 생성하지 않고, Kubernetes Ingress를 통해 생성할 것인가?
- 모니터링: EKS 내부에서 지표를 수집하고 도쿄 Prometheus로 remote_write할 것인가?
- DR: AWS 장애 감지 직후가 아니라, Azure에서 로그인과 기록 조회를 확인한 뒤 DNS를 전환할 것인가?
