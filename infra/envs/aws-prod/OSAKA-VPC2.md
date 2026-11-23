# 오사카 관제망과 서울 관리 VPC 2

오사카는 Grafana 등 관제 전용 인프라다. 서울 EKS의 `kubectl` 관리 서버나 API 터널 경유지로 사용하지 않는다. 이 Terraform 코드는 Grafana 등 소프트웨어 자체를 설치하지 않는다.

| 역할 | CIDR | 출력 |
|---|---|---|
| 서울 서비스 VPC 1 | `10.10.0.0/22` | `service_vpc_id` |
| 서울 관리 VPC 2 | `10.20.0.0/24`, 2a 비공개 서브넷 `10.20.0.0/27` | `management_vpc_id`, `management_subnet_id` |
| 오사카 관제 VPC | `10.40.0.0/16`, 관제 서브넷 `10.40.0.0/27` | `osaka_observe` (VPC·서브넷·인스턴스·IP) |

서울 관리망은 네트워크만 복원한다. 전용 라우팅 테이블에 VPC 로컬 경로만 있고 IGW·NAT·관리 EC2·SSM 엔드포인트·서울 VPC 간 피어링은 없다. 이전에 삭제된 VPC/서브넷과 같은 CIDR이지만 새 ID를 사용한다. `retire_seoul_management_vpc` 운영 입력은 더 이상 사용하지 않는다.

## 오사카 접속

오사카 SSM 셸은 **관제 호스트 운영용**이다. Ubuntu 24.04 VM은 IMDSv2, 암호화된 gp3 루트 볼륨과 SSM 에이전트용 역할을 사용한다. 셸을 열려면 운영자에게 대상 인스턴스와 SSM 세션에 대한 권한이 있어야 한다. 워크스테이션에 Session Manager 플러그인이 필요하다.

```bash
ID=$(terraform output -json osaka_observe | jq -er '.instance_id')
aws ssm start-session --region ap-northeast-3 --target "$ID"
```

기존 **서울 서비스 앱 서브넷 ↔ 오사카 관제 서브넷** 리전 간 피어링은 유지한다. 서울 앱 서브넷 `10.10.0.0/24`, `10.10.1.0/24`에서만 오사카 사설 SSH(22)를 허용한다. 대시보드 3000/9090은 지정한 공인 `/32`만 허용한다. 운영자 IP·개인 키는 커밋하지 않는다. 오사카 SSM 역할에는 EKS 편집 권한이 없고 서울 private EKS API로 들어오는 오사카 전용 443 규칙도 없다.

## 적용 범위

서울 관리망 복원 대상은 `module.network`의 `aws_vpc.management`, `aws_subnet.management`, `aws_route_table.management`, `aws_route_table_association.management`뿐이다. 저장 plan에서 생성 4개, 기존 자원 변경·삭제 0개이고 두 관리 출력만 서울의 새 ID로 변경되는지 확인한다. `osaka_observe`, 서비스 VPC, 리전 간 피어링 변경이 섞이면 적용하지 않는다. 전체 `terraform apply`는 롤백된 EKS·RDS·도메인 등을 재생성할 수 있으므로 네트워크 복원용으로 사용하지 않는다.
