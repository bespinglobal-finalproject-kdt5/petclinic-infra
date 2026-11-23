# 팀원 작업 순서

## 1. 처음 한 번: 팀 저장소 복제

관리자가 부여한 Write 권한으로 초대를 수락한다. 초기 설정 PR이 main에 병합된 뒤 아래 명령을 실행한다.

```bash
git clone https://github.com/bespinglobal-finalproject-kdt5/petclinic-team.git
cd petclinic-team
```

## 2. 작업마다: 최신 main에서 작업 브랜치 만들기

```bash
git switch main
git pull --ff-only origin main
git switch -c feat/aws-network
```

브랜치 이름은 예시다. VPC를 맡았다면 `infra/envs/aws-prod/seoul-vpc1-service/`에 재사용할 `.tf` 코드를 작성하고, `infra/envs/aws-prod/`에서 모듈을 호출한다. 모듈마다 backend를 만들지 않는다. Terraform 태그는 [태그 규칙](infra/TAGS.md)을 따른다.

## 3. AWS에 접속하지 않고 검사 → push → PR

저장소 루트에서 CI와 같은 Terraform 1.12.2로 검사한다.

```bash
terraform fmt -recursive infra
terraform -chdir=infra/envs/aws-prod init -backend=false -input=false
terraform -chdir=infra/envs/aws-prod validate
git add infra/envs/aws-prod/seoul-vpc1-service/ infra/envs/aws-prod/main.tf  # 실제 작업 경로로 변경
git diff --cached --stat
git commit -m "feat: AWS 네트워크 모듈 추가"
git push -u origin feat/aws-network
```

GitHub에서 **Compare & pull request** → **base: main** 확인 → **Create pull request**. PR을 열거나 갱신하면 CI가 자동으로 시작된다. **Checks → Terraform format and validate** 결과를 보고 실패하면 같은 브랜치에 수정해서 다시 push한다. `.terraform.lock.hcl`은 커밋하되 state, 실제 backend 설정, 자격 증명, 저장 계획은 올리지 않는다.

일반 팀원은 S3에 state를 업로드하거나 `apply`하지 않는다. 병합 후 권한 있는 배포 담당자만 [배포 절차](infra/STATE.md)에 따라 실행한다.
