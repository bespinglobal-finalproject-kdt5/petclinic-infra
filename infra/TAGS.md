# AWS·Azure 공통 태그

태그를 지원하는 자원에는 아래 세 가지를 붙입니다.

| 태그 | 무엇을 적나요? | 사용할 값 |
|---|---|---|
| `project` | 어느 프로젝트인가요? | 항상 `petclinic` |
| `environment` | 어떤 환경인가요? | 운영은 `prod`, 재해복구는 `dr` |
| `component` | 주로 어떤 일을 하나요? | `network`, `app`, `database`, `management`, `monitoring` 중 하나 |

## 적용 예시

| 자원 | project | environment | component |
|---|---|---|---|
| AWS 관리용 EC2 (`kubectl`) | `petclinic` | `prod` | `management` |
| AWS EKS (Angular·Spring 실행) | `petclinic` | `dev` | `app` |
| AWS RDS MySQL | `petclinic` | `prod` | `database` |
| Azure 복구용 앱 VM | `petclinic` | `dr` | `app` |

EKS 서브넷 탐색처럼 서비스 동작에 필요한 시스템 태그는 공통 태그와 별도로 유지합니다.
