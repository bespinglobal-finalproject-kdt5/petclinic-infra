# 오사카 관제망과 서울 관리 VPC 2

오사카에는 향후 관제용 VPC·서브넷과 SSM IAM 구성을 보존한다. 서울 관리 VPC 2는 서울 EKS 관리용으로 예약한 별도 네트워크다.

| 역할 | CIDR | 출력 |
|---|---|---|
| 서울 서비스 VPC 1 | `10.10.0.0/22` | `service_vpc_id` |
| 서울 관리 VPC 2 | `10.20.0.0/24`, 2a 비공개 서브넷 `10.20.0.0/27` | `management_vpc_id`, `management_subnet_id` |
| 오사카 관제 VPC | `10.40.0.0/16`, 관제 서브넷 `10.40.0.0/27` | `osaka_observe` (VPC·서브넷 ID) |

서울 관리망은 네트워크만 복원한다. 전용 라우팅 테이블에 VPC 로컬 경로만 있고 IGW·NAT·관리 EC2·SSM 엔드포인트·서울 VPC 간 피어링은 없다. 이전에 삭제된 VPC/서브넷과 같은 CIDR이지만 새 ID를 사용한다. `retire_seoul_management_vpc` 운영 입력은 더 이상 사용하지 않는다.

## 오사카 SSM과 라우팅

`petclinic-prod-osaka-ssm` IAM 역할과 인스턴스 프로필, `session-manager-agent` 인라인 정책이 남아 있다. EC2와 루트 디스크는 종료·삭제되어 현재 Session Manager 접속 대상은 없다.

서브넷은 VPC 기본 라우팅 테이블을 사용한다. IGW와 서울 피어링을 제거해 VPC 로컬 경로만 있다. 향후 SSM 접속을 복원하려면 SSM Agent가 설치된 호스트에 프로필을 연결하고 SSM 서비스로 통신할 경로를 구성한다.

## 서울 관리망 복원 범위

서울 관리망을 복원할 때의 대상은 `module.network`의 `aws_vpc.management`, `aws_subnet.management`, `aws_route_table.management`, `aws_route_table_association.management`다. 네 자원이 모두 삭제된 상태에서 복원한다면, 저장한 plan에 생성 4개와 두 관리 출력의 새 ID만 포함되는지 확인한 뒤 적용한다. 전체 환경 plan에는 CloudFront 배포와 도메인 레코드 생성도 포함될 수 있다.
