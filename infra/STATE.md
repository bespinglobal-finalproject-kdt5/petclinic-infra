# Terraform 실행과 state 관리

GitHub Actions는 PR에서 형식 검사, backend 없는 초기화, 구성 검증 및 AWS mock plan 테스트를 실행한다. 실계정 대상 plan이나 apply는 실행하지 않는다. CI는 backend를 연결하지 않으며 AWS 자격 증명이 필요 없다. 병합만으로 배포되지 않는다. 실제 `plan`과 `apply`는 배포 권한을 부여받은 담당자가 최신 `main`으로 수동 실행한다.

| 작업 폴더 | 공유 state |
|---|---|
| `envs/aws-prod/` | 서울 `ap-northeast-2` · `s3://petclinic-prod-tfstate-seoul/petclinic/aws-prod/terraform.tfstate` (S3 버전 관리·네이티브 잠금) |
| `envs/azure-dr/` | 별도 비공개 Azure Blob (향후 구성). AWS 자격 증명이나 state에 의존하지 않는다. |

개인·브랜치·모듈별 운영 state는 만들지 않는다. State는 DB 백업이 아니며 비밀 값이 들어갈 수 있다. state, 백업, plan은 Git·PR에 올리지 않는다. `.terraform.lock.hcl`은 provider 버전 기록이므로 커밋한다.

## AWS 관리자: 배포 전 한 번 준비

- 비공개 S3 버킷을 준비하고 퍼블릭 액세스 차단, 기본 암호화, 버전 관리를 확인한다. 이 backend 설정은 버킷을 생성하지 않는다. 버킷 리전은 서비스 리전과 달라도 된다.
- 담당자에게 실제 버킷 이름, 리전, 사용할 AWS 계정과 역할을 전달한다. 액세스 키를 Git이나 채팅에 공유하지 않는다.
- 담당 역할에 해당 prefix의 `s3:ListBucket`, state 객체의 `GetObject`·`PutObject`, 같은 경로의 `.tflock` 객체에 `GetObject`·`PutObject`·`DeleteObject`를 허용한다. 고객 관리 KMS 키를 쓴다면 해당 키 권한도 확인한다. 리소스 배포 권한은 backend 권한과 별개다.

## 기존 체크아웃을 서울에 다시 연결

2026년 11월 26일 운영 state를 오사카에서 서울로 이전했다. 키는 `petclinic/aws-prod/terraform.tfstate`이며 원본의 lineage와 serial을 보존했다. 서울 버킷에는 S3 버전 관리, SSE-S3 암호화, 퍼블릭 액세스 차단과 네이티브 잠금을 사용한다.

서울에는 전환 시점의 최신 state 한 버전부터 보관한다. 오사카 버킷 `petclinic-prod-tfstate-osaka`과 그 안의 과거 state·도쿄 보관본은 폐기 대상이다. 구 버킷을 가리키는 체크아웃에서는 배포를 중단하고 아래 절차로 서울에 연결한다.

배포 역할에 서울 버킷의 state 및 잠금 권한을 부여한다. 기존에 `-backend-config=backend.hcl`을 사용했다면 로컬 override를 [서울 예시](envs/aws-prod/backend.hcl.example)에 맞춘 뒤 연결한다. 아래 명령은 이미 이전된 state에 연결하는 절차다.

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

복구가 필요하면 모든 writer를 멈추고 서울의 최신 버전을 먼저 보존한다. 서울 운영 키의 버전 ID와 내용을 확인하고 팀의 승인된 복구 절차를 따른다. 도쿄·오사카 시기의 과거 버전은 서울에서 복원할 수 없다. 보관본을 운영 state에 임의로 덮어쓰지 않는다.

서울 VPC·엣지 모듈 분리 이전의 state를 복원할 때는 커밋 `b6637b4`의 주소 대응표로 기존 AWS 리소스 ID와 현재 모듈 주소를 대조한다.

2026년 11월 26일 오사카 운영 state의 EKS 리소스 26개가 기존 AWS 리소스 ID를 유지한 채 `module.eks`로 이동했다(serial 78 → 79). 옛 루트 주소를 담은 백업을 복원할 때는 배포 전에 해당 버전의 EKS 주소 매핑을 사용해 이전 plan을 확인한다. [EKS 주소 매핑 원본](https://github.com/bespinglobal-finalproject-kdt5/petclinic-infra/blob/d077c40e64b6dd3233f578513db6ba5c8a1054e2/infra/envs/aws-prod/moved.tf)
