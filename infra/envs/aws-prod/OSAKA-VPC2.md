# 오사카 관제망과 서울 관리 VPC 2

오사카에는 향후 관제용 VPC·서브넷과 SSM IAM 구성을 보존한다. 서울 관리 VPC 2는 프라이빗 관리 서브넷과 퍼블릭 빌드 서브넷을 제공한다.

| 역할 | CIDR | 출력 |
|---|---|---|
| 서울 서비스 VPC 1 | `10.10.0.0/22` | `service_vpc_id` |
| 서울 관리 VPC 2 | `10.20.0.0/24`, 2a 비공개 `10.20.0.0/27`, 퍼블릭 `10.20.0.32/27` | `management_vpc_id`, `management_subnet_id`, `management_public_subnet_id` |
| 오사카 관제 VPC | `10.40.0.0/16`, 관제 서브넷 `10.40.0.0/27` | `osaka_observe` (VPC·서브넷 ID) |

서울 VPC 2의 프라이빗 관리 서브넷은 VPC 로컬 경로를 사용한다. 빌드 서브넷의 기본 경로는 서울 관리 IGW를 가리킨다. 빌드 EC2는 이 경로로 SSM과 패키지 저장소에 접속한다. [서울 관리 퍼블릭 라우팅](seoul-vpc2-management/main.tf)

## 오사카 SSM과 라우팅

`petclinic-prod-osaka-ssm` IAM 역할과 인스턴스 프로필, `session-manager-agent` 인라인 정책이 남아 있다. EC2와 루트 디스크는 종료·삭제되어 현재 Session Manager 접속 대상은 없다.

서울 VPC 1이 피어링을 요청하고 오사카가 수락한다. 서울 앱 테이블은 관제 서브넷 `10.40.0.0/27`을 피어링으로 보낸다. 오사카 서브넷에 연결된 `osaka-observe-peer-rtb`에는 서울 앱 대역 `10.10.0.0/24`, `10.10.1.0/24` 두 개의 반환 경로가 있다. 오사카에는 인터넷 기본 경로가 없다. [오사카 피어링과 경로](osaka-monitoring/peering.tf) · [서울 VPC 1 경로](seoul-vpc1-service/main.tf)
