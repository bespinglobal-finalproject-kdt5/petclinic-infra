# Azure 재해복구 환경

`infra/envs/azure-dr/`는 Azure DR 구성을 위한 예약 디렉터리다. 현재 이 디렉터리에는 README만 있으며 Terraform 루트, Azure provider, backend, 리소스 정의는 아직 없다. 현재 실행 가능한 운영 루트는 [AWS 운영 환경](../aws-prod/README.md)이다.

| 설계 항목 | 현재 기준 |
|---|---|
| 네트워크 | Azure DR용으로 `10.30.0.0/24` 예약 |
| 서브넷 후보 | 복구용 VM `10.30.0.0/27`, MySQL `10.30.0.32/27` |
| 후속 구현 | 복구 네트워크·VM·MySQL·Key Vault와 별도 Azure Blob state |
| 환경 태그 | DR 환경의 `environment` 값은 `azure_dr` |

[대역 예약 근거](../../NETWORK.md) · [state 분리 계획](../../STATE.md) · [공통 태그](../../TAGS.md)
