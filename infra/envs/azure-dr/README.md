# Azure 재해복구 환경

`infra/envs/azure-dr/`는 Korea Central DR PoC Terraform 루트다. 포털 리소스 그룹 `FINAL`을 data로 읽고 VNet·사설 Flexible Server·점프 VM을 만든다. Application Gateway와 Key Vault는 아직 없다. 이 저장소에서 배포할 수 있는 운영 루트는 계속 [AWS 운영 환경](../aws-prod/README.md)이다. [운영 토폴로지](../../../docs/architecture/production-topology.md)

구독 ID, 노트북 IP, SSH 공개키, DB 비밀번호는 `terraform.tfvars`에만 둔다. 예시는 [terraform.tfvars.example](terraform.tfvars.example)다. `*.tfvars`는 Git에 올리지 않는다.

| 항목 | 현재 기준 |
|---|---|
| VNet | `Services-VNet` `10.30.0.0/25` (본선 예약 `10.30.0.0/24`의 앞절반) |
| 프라이빗 | `Pet-DR-private-1` `10.30.0.0/27`, Ubuntu 24.04 VM, SSH 22는 `my_ip`만 |
| DB | `Pet-DR-db-1` `10.30.0.32/27` 위임, PostgreSQL 16 Flexible Server, 공인 접속 꺼짐 |
| NAT | 프라이빗·DB 서브넷에 연결. 출구 `Public-IP`를 RDS SG `/32`에 넣는다 |
| 접속 | 노트북 → VM 공인 IP SSH → VM에서 사설 FQDN으로 `psql` |
| 자격 증명과 state | Key Vault와 Azure Blob backend는 후속. AWS 운영 state는 서울 S3 |
| 환경 태그 | DR 환경의 `environment` 값은 `azure_dr` |
| 후속 | 컨테이너, Route 53 80/443 |

로컬에서 `terraform -chdir=infra/envs/azure-dr init` 후 `plan`한다. 병합은 코드 반영이고 `apply`는 별도 승인이다. GitHub Actions는 `.tf` 파일이 있는 환경을 `init -backend=false`와 `validate`한다. mock 테스트는 AWS 운영 루트만 대상으로 한다.

[CI 정의](../../../.github/workflows/terraform-check.yml) · [서울 RDS 정의](../aws-prod/seoul-vpc1-service/rds-database.tf) · [대역 예약 근거](../../NETWORK.md) · [state 분리 계획](../../STATE.md) · [공통 태그](../../TAGS.md)
