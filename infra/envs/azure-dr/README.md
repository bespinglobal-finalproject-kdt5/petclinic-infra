# Azure 재해복구 환경

`infra/envs/azure-dr/`는 서울 리전 장애에 대비해 Azure 복구 환경의 네트워크 대역을 예약한 디렉터리다. 이 저장소에서 배포할 수 있는 환경은 AWS 운영 루트이며, Azure 디렉터리에는 아직 Terraform 코드가 없다. [AWS 운영 가이드](../aws-prod/README.md) · [운영 토폴로지](../../../docs/architecture/production-topology.md)

| 설계 항목 | 현재 기준 |
|---|---|
| 네트워크 | Azure DR용으로 `10.30.0.0/24` 예약 |
| 서브넷 후보 | 복구용 앱 VM `10.30.0.0/27`, 복구 DB `10.30.0.32/27`. 기존 대역표의 MySQL 표기는 설계 당시의 후보다. |
| 앱과 데이터 | 서울에서 실행되는 Angular·Spring REST 앱의 복구 대상은 Azure VM이다. 원본 DB는 RDS PostgreSQL 16이며, Azure 복구 DB와 데이터 복제·원복은 이 저장소에서 아직 구성하지 않았다. |
| 자격 증명과 state | Azure Key Vault와 별도 Azure Blob backend를 계획하고 있다. 현재 AWS 운영 state는 오사카 S3에 있다. |
| 환경 태그 | DR 환경의 `environment` 값은 `azure_dr` |

GitHub Actions는 `.tf` 파일이 있는 환경을 초기화하고 검증한다. 현재 PR에서 실행하는 mock 테스트는 AWS 운영 루트를 대상으로 한다. [CI 정의](../../../.github/workflows/terraform-check.yml) · [서울 RDS 정의](../aws-prod/seoul-vpc1-service/rds-database.tf) · [대역 예약 근거](../../NETWORK.md) · [state 분리 계획](../../STATE.md) · [공통 태그](../../TAGS.md)
