# Azure 재해복구 환경

`infra/envs/azure-dr/`는 Korea Central DR PoC Terraform 루트다. 포털 리소스 그룹 `FINAL`을 data로 읽고 VNet·사설 Flexible Server·점프 VM을 만든다. Application Gateway와 Key Vault는 아직 없다. 이 저장소에서 배포할 수 있는 운영 루트는 계속 [AWS 운영 환경](../aws-prod/README.md)이다. [운영 토폴로지](../../../docs/architecture/production-topology.md)

구독 ID, 노트북 IP, SSH 공개키, DB 비밀번호는 `terraform.tfvars`에만 둔다. 예시는 [terraform.tfvars.example](terraform.tfvars.example)다. `*.tfvars`는 Git에 올리지 않는다.

| 항목 | 현재 기준 |
|---|---|
| VNet | `Services-VNet` `10.30.0.0/25` (본선 예약 `10.30.0.0/24`의 앞절반) |
| 프라이빗 | `Pet-DR-private-1` `10.30.0.0/27`, Ubuntu 24.04 VM, SSH 22는 `my_ip`만 |
| DB | `Pet-DR-db-1` `10.30.0.32/27` 위임, PostgreSQL 16 Flexible Server, `Standard_B2ats_v2`(2 vCore, 1 GiB), 공인 접속 꺼짐 |
| NAT | VM·DB 서브넷이 인터넷으로 송신할 때 `Public-IP`를 쓴다. 서울 사설 RDS로의 접근에는 두 클라우드 사이의 라우팅이 별도로 필요하다. |
| 접속 | 노트북 → VM 공인 IP SSH → VM에서 사설 FQDN으로 `psql` |
| 자격 증명과 state | Azure CLI로 로그인한 운영자가 Entra ID로 전용 Blob 컨테이너에 접근한다. DB 관리자 비밀번호가 포함되는 state는 팀 배포 권한으로 보호한다. |
| 환경 태그 | DR 환경의 `environment` 값은 `azure_dr` |
| 후속 | 컨테이너, Route 53 80/443 |

### PR에서 검증하는 항목

GitHub Actions는 두 환경에서 `fmt`, `init -backend=false -lockfile=readonly`, `validate`, `test`를 실행한다. [Azure 테스트](tests/dr.tftest.hcl)는 mock provider로 서브넷·NAT 연결, PostgreSQL의 위임 서브넷·사설 DNS·공인 접속 차단, VM의 NIC·SSH 허용 범위를 검사한다. CI에는 Azure 자격 증명이 필요 없다.

### 팀원이 Azure 환경에 연결하는 방법

1. `az login` 후 `az account set --subscription <구독-ID>`로 `FINAL`이 있는 구독을 선택한다. 로컬 입력은 [예시 파일](terraform.tfvars.example)을 참고한다.
2. 운영자의 Entra 보안 그룹에 `tfstate` 컨테이너 범위로 `Storage Blob Data Contributor`를 부여한다. VM·DB를 만들 리소스 그룹 권한은 별도로 관리한다.
3. 처음 체크아웃했다면 저장소 루트에서 아래 명령을 실행한다. 첫 배포 전 검토 대상은 Azure DR 리소스다. 이미 로컬에서 배포한 이력이 있다면 먼저 [기존 state 이전 절차](../../STATE.md)를 확인한다.

```bash
terraform -chdir=infra/envs/azure-dr init -lockfile=readonly
terraform -chdir=infra/envs/azure-dr plan
```

[CI 정의](../../../.github/workflows/terraform-check.yml) · [서울 RDS 정의](../aws-prod/seoul-vpc1-service/rds-database.tf) · [대역 예약 근거](../../NETWORK.md) · [환경별 state](../../STATE.md) · [공통 태그](../../TAGS.md)
