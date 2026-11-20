# Terraform state 관리 규칙

State는 Terraform이 코드와 실제 자원을 연결하는 기록이다. 환경별로 한 벌씩 관리하며, 재사용 부품인 `modules/`에는 별도 state를 만들지 않는다.

| 실행 위치 | 원격 state 저장 위치 |
|---|---|
| `infra/envs/aws-prod/` | AWS 운영 환경 전용 비공개 S3 버킷 |
| `infra/envs/azure-dr/` | Azure DR 환경 전용 비공개 Azure Blob 컨테이너 |

Azure 복구 작업은 AWS의 state나 자격 증명에 의존하지 않게 한다.

- **접근:** 저장소를 암호화하고 읽기·쓰기 권한을 필요한 담당자와 배포 주체에만 부여한다. State와 백업은 비밀 값을 포함할 수 있으므로 Git이나 PR에 올리지 않는다. `.terraform.lock.hcl`은 state가 아니라 provider 버전 잠금 파일이므로 커밋한다.
- **동시 작업:** 환경마다 backend 잠금을 사용하고 한 번에 하나의 `apply`만 실행한다. 잠금 오류가 나면 먼저 다른 작업이 진행 중인지 확인한다.
- **복구:** 원격 저장소의 버전 관리를 켠다. State를 직접 편집·삭제하지 않으며 복원 전에는 진행 중인 작업을 멈추고 복원할 버전을 팀과 확인한다.

이 문서는 구축 기준이다. 실제 저장소와 backend 잠금은 첫 환경 배포 전에 구성하고 확인한다.
