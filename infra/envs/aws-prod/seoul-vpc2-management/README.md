# 서울 관리 VPC 2

`seoul_vpc2` 모듈은 관리 VPC `10.20.0.0/24`와 두 서브넷을 서울의 첫 번째 입력 AZ(운영 2a)에 배치한다. 2026-11-23 기준 퍼블릭 서브넷의 빌드 EC2가 실행 중이다. 프라이빗 관리 EC2와 SSM 인터페이스 엔드포인트는 Terraform에 정의돼 있고 운영 적용 대기 중이다. [VPC·서브넷·서버 연결](main.tf)

| 항목 | 빌드 서버 | 프라이빗 관리 서버 |
|---|---|---|
| EC2 이름 | `petclinic-prod-build-server` | `petclinic-prod-management-server` |
| 서브넷 | 퍼블릭 `10.20.0.32/27` | 프라이빗 `10.20.0.0/27` |
| 인스턴스 | 온디맨드 `m7i.large`, 2 vCPU / 8 GiB | 온디맨드 `t3.small`, 2 vCPU / 2 GiB |
| 루트 디스크 | 암호화된 gp3 50 GiB | 암호화된 gp3 30 GiB |
| 송신 | 공인 IPv4와 관리 IGW로 TCP 80·443 허용 | 공인 IP 없이 엔드포인트 보안 그룹으로 TCP 443 허용 |
| 접속 대상 출력 | `build_instance_id` | 적용 후 `management_instance_id` |

두 서버는 동일한 Canonical Ubuntu 24.04 LTS x86_64 AMI 릴리스를 사용한다. 각각 전용 SSM IAM 역할·인스턴스 프로필을 사용하며 IMDSv2를 요구한다. SSH 인바운드 규칙과 추가 패키지 설치용 user data는 없다. EC2를 중지하면 루트 디스크가 보존되고, 인스턴스를 종료하면 루트 디스크도 삭제된다. [빌드 EC2](build-server/main.tf) · [관리 EC2](management-server/main.tf)

## 프라이빗 관리 서버

프라이빗 서브넷 테이블에는 VPC 로컬 경로만 있다. 적용하면 그 서브넷에 `ssm`과 `ssmmessages` 인터페이스 엔드포인트를 생성하고 VPC의 DNS 호스트 이름 기능을 활성화한다. 관리 EC2의 SSM Agent는 엔드포인트의 사설 IP로 HTTPS 연결을 시작한다. 프라이빗 DNS가 VPC 전체에 적용되므로 엔드포인트 보안 그룹은 기존 빌드 서버 보안 그룹에서도 TCP 443을 허용한다. [엔드포인트 및 보안 그룹](management-server/ssm-endpoints.tf)

서울 VPC 1–오사카 피어링은 VPC 2의 관리 경로에 포함되지 않는다. 별도 담당자가 관리 EC2에서 비공개 EKS API를 사용하려면 VPC 1까지의 네트워크 경로와 클러스터 권한을 구성해야 한다. [서울·오사카 라우팅](../OSAKA-VPC2.md)

## Session Manager 접속

AWS CLI에 Session Manager 플러그인이 설치돼 있고 세션을 시작할 권한이 있어야 한다. 아래 명령은 운영 S3 backend를 초기화한 체크아웃의 저장소 루트에서 실행한다. 빌드 서버에는 지금 접속할 수 있다.

```sh
instance_id=$(terraform -chdir=infra/envs/aws-prod output -raw build_instance_id)
aws ssm start-session --profile default --region ap-northeast-2 --target "$instance_id"
```

관리 서버는 운영 적용 후 SSM에 등록되면 다음 명령을 사용한다.

```sh
instance_id=$(terraform -chdir=infra/envs/aws-prod output -raw management_instance_id)
aws ssm start-session --profile default --region ap-northeast-2 --target "$instance_id"
```

VPC ID는 `management_vpc_id`, 프라이빗·퍼블릭 서브넷 ID는 각각 `management_subnet_id`와 `management_public_subnet_id`로 조회한다. [루트 출력](../outputs.tf)
