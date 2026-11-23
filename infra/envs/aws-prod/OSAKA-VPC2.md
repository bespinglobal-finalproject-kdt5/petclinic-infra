# VPC 2: 서울 VPC 1 앱망에서 오사카 관제 VM으로 사설 SSH

서비스 VPC 1은 서울 `10.10.0.0/22`에 유지한다. Azure DR 예약과 충돌하지 않도록 오사카는 `10.40.0.0/16`, 관제 서브넷은 `10.40.0.0/27`이다. 오사카 모듈과 피어링 수락만 `aws.osaka`를 사용한다. S3 backend는 바꾸지 않으며 원본 디렉터리에서 따로 적용하지 않는다.

| 경로 | 설정 |
|---|---|
| 서울 → 오사카 | 서울 앱 서브넷 `10.10.0.0/24`, `10.10.1.0/24`의 기존 라우팅 테이블에 관제 서브넷 `/27` → 피어링 경로 추가. `0.0.0.0/0` → 기존 NAT 유지. DB·퍼블릭·기존 관리 서브넷에 피어 경로 없음. |
| 오사카 → 서울 | 위 두 앱 CIDR로 향하는 반환 경로만 같은 피어로 설정. IGW 기본 경로는 유지. |
| SSH | 서울 앱망에서 VM **사설 IP**의 TCP 22로 연결. 서울 NAT EIP, 공인 인터넷, 운영자 PC의 공인 IP는 22번 허용 대상이 아니다. 접속원 SG egress/NACL 및 개인 키는 별도 확인한다. |
| 대시보드 | 공인 IP TCP 3000/9090은 비공개 변수 `osaka_admin_ipv4`의 한 주소(`/32`)만 허용. VM outbound는 소프트웨어 다운로드용 HTTP/HTTPS. |

원본과 같은 Canonical Ubuntu 24.04 LTS amd64 / `t3.medium` / gp3 30 GiB를 사용한다. IMDSv2와 루트 볼륨 암호화를 적용한다. 실제 IP나 개인 키를 커밋하지 않는다. 이 코드는 관제 소프트웨어, EKS, SSH 출발용 서버를 설치/생성하지 않는다. EC2·공인 IPv4 및 리전 간 데이터 전송에는 비용이 발생할 수 있다.

## 기본 관리 접속: SSM Session Manager

운영자 PC에 AWS CLI v2와 Session Manager 플러그인이 필요하다. 오사카 콘솔의 EC2 → 인스턴스 → 연결 → Session Manager로 접속해도 된다. PEM, SSH 클라이언트 및 인터넷 22번 인바운드는 필요 없다.

```bash
ID=$(aws ec2 describe-instances --region ap-northeast-3 --filters Name=tag:Name,Values=osaka-observe Name=instance-state-name,Values=running --query 'Reservations[0].Instances[0].InstanceId' --output text)
aws ssm start-session --region ap-northeast-3 --target "$ID"
```

운영자 IAM에는 대상 인스턴스/세션 문서에 대한 StartSession 및 자기 세션 권한이 필요하다. EC2 역할은 SSM 에이전트 등록·메시지 채널용일 뿐이다. 서버에서 향후 서울 EKS를 관리하려면 별도 클러스터와 kubectl, AWS CLI, `eks:DescribeCluster`, EKS Access Entry/권한 및 피어링을 통한 API 443 왕복 경로·SG를 준비해야 한다. SSM 접속 자체는 EKS 관리 권한을 부여하지 않는다.
## 단계적 전환

1. 두 리전과 state에서 기존 VPC/서브넷/관제 호스트의 소유권을 대조한다. 중복이 있으면 import부터 검토한다. `osaka-key`(또는 지정한 오사카 키 페어)에 대응하는 개인 키를 확인한다. 서울 계정/리전/AZ 변수는 기존 값을 유지한다. `osaka_admin_ipv4`는 원래 관리 PC의 공인 IPv4를 로컬에서만 제공한다.
2. `retire_seoul_management_vpc=false`를 유지한다. 아래 범위는 오사카 7개 + SSM IAM 3개 + 피어링 요청/수락 2개 생성, 서울 앱 라우팅 테이블만 변경, 삭제 0개다. 기존 서울 관리망 4개의 주소 이동은 `no-op`이어야 한다. 비대상 EKS/CloudFront/DNS가 섞이는 전체 plan을 그대로 적용하지 않는다.

```bash
terraform plan -target=module.osaka_observe \
  -target=module.network.aws_route_table.service_app \
  -target=module.network.aws_vpc.management -target=module.network.aws_subnet.management \
  -target=module.network.aws_route_table.management -target=module.network.aws_route_table_association.management \
  -out=stage1.tfplan
terraform show stage1.tfplan
# 검토·승인 후에만 terraform apply stage1.tfplan
```

3. 오사카 VM 상태 검사 2/2, 피어링 `active`, 양쪽 라우팅과 SG를 확인한다. 출력 `osaka_observe.private_ip`로 **서울 앱 서브넷의 호스트**에서 `ssh -i <키경로> ubuntu@<오사카-사설-IP>`를 실행한다. VPN 등으로 접속하더라도 오사카에 보이는 출발지 IP가 허용 대역에 속해야 한다. 서울에 테스트 호스트가 없으면 실제 SSH 성공으로 간주하지 않는다.
4. 연결 검증 및 기존 서울 관리망의 의존성(ENI, 인스턴스, endpoint 등) 확인 전에는 기존 VPC를 지우지 않는다. 모두 확인한 뒤 `retire_seoul_management_vpc=true`를 운영 입력에 지속 설정하고, 서울 기존 관리망의 VPC·서브넷·라우팅 테이블·연결 4개만 제거하는 별도 plan을 검토한다. 이후 `management_vpc_id`/`management_subnet_id`가 오사카 ID와 일치해야 한다. 플래그를 false로 되돌리면 서울 관리망이 재생성될 수 있다.
