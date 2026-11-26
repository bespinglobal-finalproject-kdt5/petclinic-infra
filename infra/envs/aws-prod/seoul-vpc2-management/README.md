# 서울 관리 VPC 2

운영 루트의 `module.seoul_vpc2`는 관리 VPC `10.20.0.0/24`를 만들고 첫 번째 입력 AZ(운영 2a)에 두 서브넷을 둔다. 퍼블릭 서브넷의 빌드 서버에 EIP를 연결하고, EKS와 RDS를 관리하는 서버는 프라이빗 서브넷에 배치한다. [운영 루트](../main.tf) · [VPC와 서브넷](main.tf) · [공통 AMI와 서버 연결](servers.tf)

| 항목 | 빌드 서버 | 프라이빗 관리 서버 |
|---|---|---|
| EC2 이름 | `petclinic-prod-build-server` | `petclinic-prod-management-server` |
| 서브넷 | 퍼블릭 `10.20.0.32/27` | 프라이빗 `10.20.0.0/27` |
| 인스턴스 | 온디맨드 `m7i.large`, 2 vCPU / 8 GiB | 온디맨드 `t3.small`, 2 vCPU / 2 GiB |
| 루트 디스크 | 암호화된 gp3 50 GiB | 암호화된 gp3 30 GiB |
| SSH 수신 | EIP에서 IPv4 `0.0.0.0/0`의 TCP 22 허용 | 사설 IP로 라우팅 가능한 IPv4 출발지에서 TCP 22 허용(`0.0.0.0/0`) |
| 송신 | 인터넷으로 TCP 22·80·443 허용 | SSM 엔드포인트 443, 인터넷 80·443, 피어링으로 EKS API 443·RDS 5432 허용 |
| 접속 대상 출력 | `build_instance_id` | `management_instance_id` |

두 서버는 동일한 Canonical Ubuntu 24.04 LTS x86_64 AMI 릴리스를 사용한다. 각각 전용 SSM IAM 역할·인스턴스 프로필을 사용하며 IMDSv2를 요구한다. 빌드 서버의 SSH 인증에는 인스턴스 안에 등록한 사용자 키 등이 필요하다. EC2를 중지하면 루트 디스크가 보존되고, 인스턴스를 종료하면 루트 디스크도 삭제된다. [빌드 EC2](build-server/main.tf) · [관리 EC2](management-server/main.tf)

## 프라이빗 관리 서버

프라이빗 서브넷은 관리 NAT를 기본 경로로 사용한다. 이 서브넷에는 `ssm`과 `ssmmessages` 인터페이스 엔드포인트가 있고, VPC의 DNS 호스트 이름 기능과 두 엔드포인트의 프라이빗 DNS가 활성화돼 있다. 관리 EC2의 SSM Agent는 엔드포인트의 사설 IP로 HTTPS 연결을 시작한다. 프라이빗 DNS가 VPC 전체에 적용되므로 엔드포인트 보안 그룹은 기존 빌드 서버 보안 그룹에서도 TCP 443을 허용한다. [엔드포인트 및 보안 그룹](management-server/ssm-endpoints.tf)

### 서비스 VPC로 가는 경로

| 대상 | 관리 EC2에서 연결하는 방식 |
|---|---|
| EKS 비공개 API · TCP 443 | 관리 서브넷은 서비스 VPC `10.10.0.0/22`로, 앱 서브넷은 관리 VPC `10.20.0.0/24`로 가는 트래픽을 같은 피어링으로 보낸다. 클러스터 보안 그룹은 관리 EC2의 사설 IP `/32`를 허용한다. 관리 EC2 역할에는 `eks:DescribeCluster`와 EKS 클러스터 관리자 접근 권한이 있다. [보안 그룹과 피어링](../network-connections.tf) · [관리 IAM 역할 연결](../management-access.tf) · [EKS 접근 항목](../eks/cluster.tf) |
| RDS PostgreSQL · TCP 5432 | 관리 서버 보안 그룹은 두 DB 서브넷을 포함한 `10.10.2.64/26`으로 송신한다. RDS 보안 그룹은 관리 EC2의 사설 IP `/32`에서 수신하고, DB 서브넷은 같은 `/32`로 가는 응답을 피어링으로 보낸다. [TCP 5432 규칙](../network-connections.tf) · [DB 반환 경로](../seoul-vpc1-service/main.tf) |

## Session Manager 접속

AWS CLI에 Session Manager 플러그인이 설치돼 있고 세션을 시작할 권한이 있어야 한다. 아래 명령은 운영 S3 backend를 초기화한 체크아웃의 저장소 루트에서 실행한다. 빌드 서버에 접속하려면 다음 명령을 사용한다.

```sh
instance_id=$(terraform -chdir=infra/envs/aws-prod output -raw build_instance_id)
aws ssm start-session --profile default --region ap-northeast-2 --target "$instance_id"
```

프라이빗 관리 서버에 접속하려면 다음 명령을 사용한다.

```sh
instance_id=$(terraform -chdir=infra/envs/aws-prod output -raw management_instance_id)
aws ssm start-session --profile default --region ap-northeast-2 --target "$instance_id"
```

VPC ID는 `management_vpc_id`, 프라이빗·퍼블릭 서브넷 ID는 각각 `management_subnet_id`와 `management_public_subnet_id`로 조회한다. [루트 출력](../outputs.tf)
