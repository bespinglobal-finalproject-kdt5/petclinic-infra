# AWS·Azure 공통 태그

태그를 지원하는 자원에는 아래 세 가지를 붙입니다.

| 태그 | 무엇을 적나요? | 사용할 값 |
|---|---|---|
| `project` | 어느 프로젝트인가요? | 항상 `petclinic` |
| `environment` | 어떤 환경인가요? | 운영은 `prod`, 재해복구는 `azure_dr` |
| `component` | 주로 어떤 일을 하나요? | `network`, `app`, `database`, `management`, `monitoring` 중 하나 |

## 적용 예시

| 자원 | project | environment | component |
|---|---|---|---|
| AWS 관리용 EC2 (`kubectl`) | `petclinic` | `prod` | `management` |
| AWS EKS (Angular·Spring 실행) | `petclinic` | `prod` | `app` |
| AWS RDS MySQL | `petclinic` | `prod` | `database` |
| Azure 복구용 앱 VM | `petclinic` | `azure_dr` | `app` |

EKS 서브넷 탐색처럼 서비스 동작에 필요한 시스템 태그는 공통 태그와 별도로 유지합니다.

AWS 운영 Terraform은 태그를 지원하는 관리 대상 자원에 대소문자를 구분하는 `Name` 태그도 붙입니다. `petclinic-prod-` 뒤에 역할과 종류를 쓰고, 서브넷 이름에는 AZ를 덧붙입니다(예: `petclinic-prod-service-vpc`, `petclinic-prod-app-subnet-2a`). 이 표시 태그는 ALB 물리 이름이나 DNS 레코드를 바꾸지 않습니다.
