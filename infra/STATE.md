# Terraform 실행과 state 관리

GitHub Actions는 PR에서 형식 검사, backend 없는 초기화, 구성 검증 및 AWS mock plan 테스트를 실행한다. 실계정 대상 plan이나 apply는 실행하지 않는다. CI는 backend를 연결하지 않으며 AWS 자격 증명이 필요 없다. 병합만으로 배포되지 않는다. 실제 `plan`과 `apply`는 배포 권한을 부여받은 담당자가 최신 `main`으로 수동 실행한다.

| 작업 폴더 | 공유 state |
|---|---|
| `envs/aws-prod/` | 오사카 `ap-northeast-3`: `s3://petclinic-prod-tfstate-osaka/petclinic/aws-prod/terraform.tfstate` (S3 버전 관리·네이티브 잠금) |
| `envs/azure-dr/` | 별도 비공개 Azure Blob (향후 구성). AWS 자격 증명이나 state에 의존하지 않는다. |

개인·브랜치·모듈별 운영 state는 만들지 않는다. State는 DB 백업이 아니며 비밀 값이 들어갈 수 있다. state, 백업, plan은 Git·PR에 올리지 않는다. `.terraform.lock.hcl`은 provider 버전 기록이므로 커밋한다.

## AWS 관리자: 배포 전 한 번 준비

- 비공개 S3 버킷을 준비하고 퍼블릭 액세스 차단, 기본 암호화, 버전 관리를 확인한다. 이 backend 설정은 버킷을 생성하지 않는다. 버킷 리전은 서비스 리전과 달라도 된다.
- 담당자에게 실제 버킷 이름, 리전, 사용할 AWS 계정과 역할을 전달한다. 액세스 키를 Git이나 채팅에 공유하지 않는다.
- 담당 역할에 해당 prefix의 `s3:ListBucket`, state 객체의 `GetObject`·`PutObject`, 같은 경로의 `.tflock` 객체에 `GetObject`·`PutObject`·`DeleteObject`를 허용한다. 고객 관리 KMS 키를 쓴다면 해당 키 권한도 확인한다. 리소스 배포 권한은 backend 권한과 별개다.

## 기존 체크아웃을 오사카에 다시 연결

현재 state는 오사카로 이전했고 구 도쿄 버킷 `petclinic-prod-tfstate`는 삭제했다. 삭제 전 도쿄 state 28개 버전을 오사카의 `archive/tokyo/petclinic/aws-prod/versions/`에 개별 객체로 복사하고, 각 보관 버전을 다시 읽어 원본과 바이트 단위로 대조했다. 원본 버전 ID·수정 시각·serial·SHA-256과 보관 객체 위치는 같은 버킷의 `archive/tokyo/petclinic/aws-prod/manifest.json`에 기록했다. 운영 키·lineage는 그대로이며, 과거 잠금 파일은 복구용 state가 아니다. 서울 워크로드·Azure DR의 리전은 바뀌지 않았다.

이 저장소의 `backend.tf`가 버킷과 리전을 지정한다. 기존에 `-backend-config=backend.hcl`을 쓰던 작업자/CI는 도쿄 override를 제거하거나 `backend.hcl.example`의 오사카 값으로 바꾼다. 기본값을 사용하는 경우 아래처럼 연결만 재설정한다. `state list`에 기존 자원이 보이지 않으면 진행하지 않는다.

```bash
git switch main
git pull --ff-only origin main
cd infra/envs/aws-prod
aws sts get-caller-identity
terraform init -reconfigure -input=false
terraform state list
terraform plan -out=reviewed.tfplan  # 원하는 워크로드 변경이 있을 때만
```

대상과 추가·변경·삭제 내역을 확인한 뒤 **해당 계획만** `terraform apply reviewed.tfplan`으로 적용한다. backend 초기화만으로는 VPC가 생기지 않지만 실제 네트워크 계획을 적용하면 자원이 생성된다. 계획에는 확인한 `aws_account_id`, `aws_region`, `availability_zones`를 입력해야 한다. 로컬 `terraform.tfvars`에 넣을 경우 Git에 올리지 않는다. 같은 환경에 한 번에 하나의 apply만 실행한다. 잠금이 있으면 진행 중인 작업부터 확인하며, state의 직접 편집·삭제 및 임의 잠금 해제는 금지한다. 복구 시 작업을 멈추고 복원할 객체 버전을 팀과 확인한다.

복구가 필요하면 모든 writer를 멈추고 오사카의 최신 버전을 먼저 보존한다. manifest로 보관본의 체크섬과 버전을 확인하고 팀의 승인된 복구 절차를 따른다. `archive/`를 백엔드로 연결하거나 이전 도쿄 버킷 이름을 다시 사용하지 않는다. 보관본을 운영 state에 임의로 덮어쓰지 않는다.
