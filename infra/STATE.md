# Terraform state 관리 규칙

State는 Terraform이 코드와 실제 자원을 연결하는 기록이다. 환경별로 한 벌씩 관리하며, 재사용 부품인 `modules/`에는 별도 state를 만들지 않는다.

Terraform 코드는 GitHub에서 리뷰하고, 실행은 GitHub Actions가 맡는다. 아래 경로는 실행 서버가 아니라 환경별 작업 폴더다. State는 GitHub 저장소가 아니라 각 클라우드에 보관한다.

| 환경별 작업 폴더 | 실행 주체 | 원격 state 저장 위치 |
|---|---|---|
| `infra/envs/aws-prod/` | GitHub Actions | AWS 운영 환경 전용 비공개 S3 버킷 |
| `infra/envs/azure-dr/` | GitHub Actions | Azure DR 환경 전용 비공개 Azure Blob 컨테이너 |

Azure 복구 작업은 AWS의 state나 자격 증명에 의존하지 않게 한다.

- **접근:** 저장소를 암호화하고 읽기·쓰기 권한을 필요한 담당자와 배포 주체에만 부여한다. State와 백업은 비밀 값을 포함할 수 있으므로 Git이나 PR에 올리지 않는다. `.terraform.lock.hcl`은 state가 아니라 provider 버전 잠금 파일이므로 커밋한다.
- **동시 작업:** 환경마다 backend 잠금을 사용하고 한 번에 하나의 `apply`만 실행한다. 잠금 오류가 나면 먼저 다른 작업이 진행 중인지 확인한다.
- **복구:** 원격 저장소의 버전 관리를 켠다. State를 직접 편집·삭제하지 않으며 복원 전에는 진행 중인 작업을 멈추고 복원할 버전을 팀과 확인한다.

이 문서는 구축 기준이다. 실제 저장소와 backend 잠금은 첫 환경 배포 전에 구성하고 확인한다.

## GitHub Actions 사용 순서

아래는 워크플로를 도입한 뒤의 절차다. 이 문서 자체는 검사나 배포를 실행하지 않는다.

1. **팀원 — PR 검사:** 작업 브랜치에서 Terraform 코드를 수정하고 `main` 대상 PR을 연다. PR의 **Checks** 탭에서 `terraform fmt -check -recursive`와 환경별 `terraform init -backend=false`, `terraform validate` 결과를 확인한다. 실패하면 해당 단계의 로그를 보고 같은 브랜치에 수정 사항을 push한다. PR 검사에는 운영 자격 증명을 주지 않는다.
2. **담당자 — 계획 검토:** 병합 후 **Actions → 해당 실행**에서 대상 환경과 커밋을 확인한다. 워크플로는 해당 환경의 원격 state로 새 `plan`을 만든다. 생성·변경·삭제 내역을 검토한다. **병합만으로 클라우드 자원이 바뀌지는 않는다.**
3. **승인자 — 실제 반영:** 계획이 의도와 같을 때만 **Review deployments → 대상 환경 → Approve and deploy**를 선택한다. `apply`는 그 실행에서 검토한 저장 계획만 사용한다. 예상 밖 삭제나 교체가 보이면 승인하지 않는다. 계획이 오래됐거나 state가 바뀌면 새 계획을 검토한다.

### 관리자가 처음 준비할 것

- 저장소 루트 `.github/workflows/`에 PR 검사 워크플로부터 추가한다. 첫 Terraform 코드로 검사가 성공한 뒤 해당 검사 이름을 `main`의 필수 검사로 지정한다.
- 배포 연결 전 **Settings → Environments**에서 `aws-prod`, `azure-dr`를 각각 만들고, 필수 승인자와 배포 허용 브랜치(`main`)를 설정한다. 각 `apply` 작업이 해당 Environment를 참조해야 승인 대기가 적용된다.
- 클라우드 권한은 GitHub OIDC로 연결하고, 계획 조회와 실제 변경 권한을 분리한다. 환경별로 backend 잠금과 실행 동시성 제한을 설정한다. 저장 계획에는 민감한 값이 있을 수 있으므로 공개 레포의 로그·댓글·공개 다운로드에 노출하지 않는다.
