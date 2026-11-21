# Petclinic EKS 설정과 정책

**상태: 서울 리전 공개 데모.** 앱 화면과 API만 인터넷에 공개한다. 운영 자격 증명과 클러스터·DB 관리 경로는 공개하지 않는다.

## 1. 요청이 어디로 가는가

| 요청 | 경로 | 이유와 경계 |
|---|---|---|
| 사용자 화면 | `mission-critical.site` → Route 53 → CloudFront → VPC Origin → 내부 ALB → 웹 NodePort `30080` → Angular `8080` | 브라우저가 EKS API나 노드 IP를 알 필요가 없다. CloudFront는 기본 경로에서 GET/HEAD만 허용한다. |
| 사용자 API | 같은 도메인의 `/petclinic/api/*` → 같은 ALB → API NodePort `30966` → Spring `9966` → RDS `5432` | 브라우저 관점에서 화면과 API의 출처가 같다. API 경로에서만 HTTPS 쓰기 메서드를 전달하며 캐시하지 않는다. |
| 클러스터 관리 | 운영자 → SSM 세션 → 관리 VPC의 EC2 → VPC 피어링 → EKS 비공개 API `443` | 관리 EC2에는 공개 IP나 SSH 인바운드가 없다. SSM 터널은 네트워크만 연결하며 Kubernetes 권한은 접속자 IAM 신원으로 다시 판정한다. |

**앱 공개 범위:** CloudFront의 웹·API 경로에 IP 허용 목록과 사용자 로그인이 없다. 누구나 같은 데모 데이터를 조회·등록·수정·삭제할 수 있으므로 실제 개인정보를 입력하지 않는다. 브라우저 TLS는 CloudFront에서 종료되며 VPC Origin에서 내부 ALB까지는 사설 HTTP:80이다. EKS 관리 API·ALB·DB는 계속 비공개다.

## 2. 클러스터와 워커 노드

- `petclinic-prod`, Kubernetes **1.36**, `STANDARD` 지원, EKS 인증 모드 `API`. 제어면은 AWS가 관리하고, Kubernetes API는 `endpoint_private_access=true`, `endpoint_public_access=false`다.
- 앱 서브넷 두 개(서울 `2a`, `2c`)에 **관리형 노드 그룹 하나**를 둔다. 노드는 AL2023 x86_64, 온디맨드 `t3.medium`; 최소·희망·최대가 모두 **2대**다. 그룹이 두 AZ를 쓰도록 한 것이지 AZ마다 항상 정확히 한 대라고 보장한 것은 아니다.
- 노드 업데이트 중 최대 비가용 노드는 1대다. 루트 디스크는 암호화한 gp3 20 GiB, IMDSv2 토큰을 요구하고 응답 hop limit은 1이다. EC2 자격 증명을 일반 앱 컨테이너에 전달하기 위한 구성이 아니다.
- HPA, Cluster Autoscaler, PodDisruptionBudget은 이 구성에 없다. 부하가 증가해도 자동으로 노드 수를 늘리지 않는다. 두 앱 AZ가 기존 단일 NAT를 사용하므로 NAT가 놓인 AZ 장애 시 다른 AZ에서도 외부 이미지 다운로드가 영향을 받을 수 있다.

## 3. IAM과 Kubernetes 권한을 어떻게 나눴는가

| 신원 | 부여한 권한 | 하지 않는 일 |
|---|---|---|
| EKS 제어면 | `AmazonEKSClusterPolicy`, EKS 서비스만 역할 인수 | 앱의 DB 암호를 읽는 역할이 아니다. |
| 워커 노드 | `AmazonEKSWorkerNodePolicy`, `AmazonEC2ContainerRegistryPullOnly` | 이미지를 pull하지만 배포 이미지를 push하거나 DB 관리자 비밀번호를 읽을 필요는 없다. |
| `kube-system:aws-node` | OIDC/IRSA로 별도 `AmazonEKS_CNI_Policy` 사용. `sub`는 해당 서비스 계정, `aud`는 STS로 제한 | Pod 네트워크 관리 권한을 일반 앱이나 전체 노드 역할에 주지 않는다. |
| 관리 EC2 | 대상 클러스터 `eks:DescribeCluster` 및 SSM 메시지 채널. EKS Access Entry의 `AmazonEKSEditPolicy`는 `petclinic` 네임스페이스에만 연결 | 이 역할은 자동으로 클러스터 관리자가 되지 않는다. 네임스페이스 편집자는 워크로드와 Secret에 영향을 줄 수 있으므로 신뢰된 운영자만 사용한다. |
| 클러스터 생성자 | 최초 생성 시 bootstrap cluster-admin | 네임스페이스 생성 등 초기 작업용이다. 대체 관리자 접근을 검증하기 전에 제거하지 않는다. |

관리 VPC에는 `ssm`, `ssmmessages`, `eks`, `sts` 인터페이스 엔드포인트를 둔다. 여기서 `eks` 엔드포인트는 AWS의 관리 API용이다. `kubectl` 트래픽은 이 엔드포인트가 아니라 **피어링을 거쳐 클러스터의 private endpoint**로 간다. SSM 터널을 사용해도 EKS CA와 TLS 서버 이름을 검증한다.

## 4. 허용 포트와 실제 격리 단위

| 출발 → 도착 | 허용 범위 |
|---|---|
| 관리 EC2 → 관리용 인터페이스 엔드포인트 / EKS API | 각 보안 그룹 사이 TCP 443. 관리 서브넷에는 인터넷 기본 경로 대신 앱 서브넷으로의 피어링 경로를 둔다. |
| CloudFront → 내부 ALB | 기존 CloudFront origin-facing 관리 접두사에서 TCP 80. 인터넷 공개 ALB가 아니다. |
| 내부 ALB → 워커 노드 | ALB SG → 노드에 연결된 클러스터 SG에 TCP 30080/30966 규칙 추가. ASG에 연결한 대상 그룹이 노드 교체를 추적한다. 별도의 공개 LoadBalancer Service나 Ingress Controller를 만들지 않는다. |
| 앱 → PostgreSQL | RDS SG는 클러스터 SG에서 오는 TCP 5432만 받는다. 관리 VPC에서 DB에 직접 연결하는 경로를 만들지 않는다. |

DB 허용 단위는 **Pod 이름이 아니라 SG**다. 같은 SG를 사용하는 다른 Pod까지 보안 그룹만으로 구분하지 않는다. Kubernetes NetworkPolicy 기반의 Pod별 격리는 이번 범위 밖이다.

## 5. Pod 운영·보안 정책

배포 근거: [`apps.yaml.in`](../deploy/k8s/apps.yaml.in). WEB·API 이미지는 서울 리전의 비공개 ECR `petclinic-prod/web`, `petclinic-prod/api`에 게시한다. ECR 태그는 immutable이고 Pod 이미지는 `@sha256:…` digest로 고정한다. 워커 IAM 역할로 이미지를 pull하므로 GHCR 토큰이나 앱용 Docker 로그인 Secret은 사용하지 않는다. ECR push 시 스캔과 별도로, 취약점 결과에 따라 배포를 자동 차단하는 게이트는 구성하지 않았다.

| 항목 | Angular `web` | Spring `api` |
|---|---|---|
| 복제 수 | 2 | 2 |
| CPU·메모리 요청 | 25m / 32 MiB | 200m / 384 MiB |
| CPU·메모리 상한 | 250m / 96 MiB | 1 CPU / 768 MiB |
| 실행 UID | 101 | 10001 |
| 상태 검사 | `/`로 readiness·liveness | startup·liveness는 프로세스 상태, readiness에는 DB 연결 포함 |

- 두 앱은 롤링 업데이트 시 `maxUnavailable: 0`, `maxSurge: 1`이다. 새 Pod가 Ready가 된 뒤 기존 Pod를 내린다. 임시 Pod를 띄울 용량이 없으면 무중단을 보장하는 것이 아니라 업데이트가 대기할 수 있다.
- AZ별 편차 `maxSkew: 1`은 `DoNotSchedule`, 호스트별 분산은 `ScheduleAnyway`다. 배포 직후 2a와 2c에서 각각 WEB 1개, API 1개가 Ready였다.
- 앱 네임스페이스에는 Pod Security Admission `restricted`를 강제한다. 두 앱 모두 non-root, 읽기 전용 루트 파일시스템, `allowPrivilegeEscalation: false`, capabilities 전체 제거, `RuntimeDefault` seccomp, 서비스 계정 토큰 자동 마운트 해제를 사용한다. 쓰기가 필요한 임시 경로만 `emptyDir`로 연다.
- RDS가 일시적으로 응답하지 않으면 API는 readiness에서 빠져 새 요청을 받지 않는다. liveness에는 DB를 넣지 않아 DB 장애 때문에 정상 JVM까지 반복 재시작하지 않는다. ALB 고정 `/health` 응답은 앱이나 DB가 정상이라는 근거가 아니다.

## 6. PostgreSQL 보호와 복구 범위

PostgreSQL **16.15**, `db.t4g.micro`, 비공개·암호화 gp3 20 GiB, **Multi-AZ DB 인스턴스**를 생성했다. 백업 보존은 7일이고 삭제 방지·최종 스냅샷을 설정했다. Multi-AZ는 같은 리전에서 장애 시 대기 DB로 전환하는 기능이며, 과거 데이터 복원이나 타 클라우드 DR을 대신하지 않는다. **DMS는 포함하지 않는다.**

RDS 관리자 비밀번호는 Secrets Manager에서 관리한다. 초기화 Job만 관리자 자격으로 스키마와 제한된 앱 계정을 만든다. Spring은 `external-postgres` 프로필, 별도 앱 계정의 Kubernetes Secret, JDBC `sslmode=verify-full`과 RDS CA를 사용한다. 시작할 때 DDL이나 샘플 데이터 삽입을 하지 않는다. Secret 내용·백업·인증서 키는 공개 저장소에 넣지 않는다.

## 7. 배포 검증 결과 (2026-11-21, 한국시간)

| 확인 방법 | 합격 기준 | 현재 상태 |
|---|---|---|
| EKS와 워커 노드 | private API, 노드 2대 Ready | 1.36 ACTIVE, public=false/private=true. 2a·2c 워커 Ready |
| 관리 EC2 역할 | 네임스페이스 범위 검증 | AWS에서 AmazonEKSEditPolicy → `petclinic` 범위 확인. 역할 자체의 `kubectl auth can-i` 양·음성 검사는 별도로 수행하지 않음 |
| WEB·API rollout 및 ALB | 각각 2/2, 대상 그룹 healthy | 두 Deployment 모두 2/2, 두 대상 그룹 모두 2/2 healthy |
| 실제 도메인 | 비인증 페이지 및 CRUD | 이전에 차단됐던 앱 NAT에서 공개 도메인으로 UI/목록 200, 등록 201, 조회 200, 수정 204, 변경값 재조회 200, 삭제 204, 삭제 후 404 확인 |
| RDS | 비공개 Multi-AZ, 암호화, 7일 백업 | available, 주 AZ 2c, MultiAZ=true, publicly accessible=false, storage encrypted=true, 백업 7일. 대기 AZ 필드는 응답에서 비어 있었음 |

ECR 배포 digest: WEB `sha256:bc1f3d75a826ee3224268b722f2a71ceb70eb1125ca53a6049e08b0102a14494`, API `sha256:6c1c5c5cda2728024949e4f2b2dc2870b1495f3dbebb69788e262c84b12ad877`. 실제 failover와 백업 복원 테스트는 수행하지 않았다.
