# 소스 변경과 WEB·WAS·DB 배치

**배포 상태:** 서울 EKS와 RDS에 배포한 뒤 CloudFront의 IP 제한을 해제해 `https://mission-critical.site`를 로그인 없는 공개 데모로 운영한다. [인프라 PR #13](https://github.com/bespinglobal-finalproject-kdt5/petclinic-infra/pull/13)의 구성이 `main`에 반영되기 전에 이전 `main`으로 apply하지 않는다.

## 바뀐 소스

| 구성 요소 | 주요 파일 | 변경 이유 |
|---|---|---|
| Angular | [`environment.prod.ts`](../spring-petclinic-angular/src/environments/environment.prod.ts), [`proxy.conf.json`](../spring-petclinic-angular/proxy.conf.json), [`src/index.html`](../spring-petclinic-angular/src/index.html) | API 주소 `localhost:9966`을 같은 출처의 `/petclinic/api/`로 변경했다. 배포 시 브라우저가 사용자 PC가 아닌 도메인의 API를 호출한다. 개발 때만 프록시가 로컬 REST로 전달한다. |
| WEB 이미지 | [Dockerfile](../spring-petclinic-angular/Dockerfile), [nginx.conf](../spring-petclinic-angular/nginx.conf) | Angular의 `dist/browser/`를 Nginx가 8080에서 제공한다. `/owners/1` 새로고침은 SPA로 복구하지만, 잘못 전달된 API는 HTML 대신 404를 반환한다. |
| Spring REST | [외부 DB 프로필](../spring-petclinic-rest/src/main/resources/application-external-postgres.properties), [기본 설정](../spring-petclinic-rest/src/main/resources/application.properties), [런타임 이미지](../spring-petclinic-rest/Dockerfile.runtime) | 기본 H2는 로컬 실습용으로 유지했다. 배포 시 `external-postgres`로 전환하고 URL·사용자·암호를 주입한다. 스키마 검증만 수행하고 테이블 생성이나 샘플 데이터 재삽입은 하지 않는다. 9966에서 실행하는 Java 21 non-root 이미지와 상태 검사 경로를 준비했다. |
| Kubernetes | [WEB/API 매니페스트](../deploy/k8s/apps.yaml.in) | 별도 이미지·Deployment·Service·상태 검사·리소스 제한을 사용한다. API readiness에 DB를 포함하지만 liveness는 DB 장애와 분리한다. |

## WEB과 WAS: 같은 앱망, 별도 프로세스와 배포 단위

사용자 요청: **브라우저 → `mission-critical.site` → CloudFront → 내부 ALB**. `/`와 화면 경로는 `web` 대상 그룹 → NodePort `30080` → Nginx `8080`; `/petclinic/api/*`는 `api` 대상 그룹 → NodePort `30966` → Spring `9966` → PostgreSQL `5432`이다. WEB이 WAS로 쿼리를 중계하는 것이 아니라 브라우저가 같은 도메인의 API 경로를 다시 호출한다. 두 앱은 각 2개 Pod로 독립적으로 롤링 업데이트하며, 같은 두 앱 서브넷과 워커 노드 그룹을 공유한다. **WEB 전용 서브넷과 WAS 전용 서브넷으로 분할한 설계는 아니다.**

## 어느 서브넷에 배치하는가

| VPC / 역할 | 서울 2a | 서울 2c | 용도 |
|---|---|---|---|
| 서비스 / public | `10.10.2.0/27` | `10.10.2.32/27` | 기존 인터넷 게이트웨이 경로. 기존 NAT는 2a에 하나이며 공개 웹 Pod를 여기에 두지 않는다. |
| 서비스 / app | `10.10.0.0/24` | `10.10.1.0/24` | 두 앱 서브넷에 내부 ALB와 워커. Pod→노드→EC2 subnet 대조 결과, 2a와 2c에 WEB 1개·WAS 1개씩 Ready. |
| 서비스 / DB | `10.10.2.64/27` | `10.10.2.96/27` | 두 서브넷의 비공개 RDS DB subnet group. 실측: 주 AZ `2c`, `MultiAZ=true`. `SecondaryAvailabilityZone`은 조회 시 값이 없어 단정하지 않았다. |
| 관리 / management | `10.20.0.0/27` | 없음 | 퍼블릭 IP 없는 관리 EC2. SSM 터널과 VPC 피어링을 통해 EKS API의 TCP 443으로 접근한다. |

## EKS와 DB 정책 요약

- EKS 1.36, 공개 API 꺼짐. 관리형 노드 그룹 한 개에 `t3.medium` 2대 고정. 노드는 IMDSv2 필수·암호화 디스크 사용. 관리 EC2 역할의 `AmazonEKSEditPolicy`는 `petclinic` 네임스페이스로 제한한다.
- WEB/WAS는 AZ별 분산 제약을 둔다. 롤링 업데이트 설정은 `maxUnavailable: 0`, `maxSurge: 1`. 앱 네임스페이스는 `restricted`; 일반 컨테이너는 non-root, 읽기 전용 루트, 추가 권한 상승 금지, 모든 Linux capability 제거, 서비스 계정 토큰 자동 마운트 해제다.
- 기존 DB의 변경이 아니라 **PostgreSQL 16.15 Multi-AZ RDS를 신규 생성**했다. `db.t4g.micro`, 암호화 gp3 20 GiB, 자동 백업 7일, 삭제 보호, 공개 접근 꺼짐. DB 초기화 Job으로 스키마와 제한된 계정을 만들고 Job은 삭제했다. Spring은 관리자가 아닌 앱 역할로 접속하며 RDS CA로 호스트 이름을 검증한다. DMS는 없다.
- 리전 내 Multi-AZ는 백업이나 멀티클라우드 DR을 대신하지 않는다. 인터넷에 공개된 것은 데모 UI와 API이며 RDS 자체는 비공개다. 실제 개인정보는 사용하지 않는다.

### 서비스 실측

`https://mission-critical.site` 화면(200), 페이지 조회(200), 테스트 보호자 생성(201) → 동일 ID 재조회(200) → 삭제(204) → 삭제 후 404를 검증했다. 이후 IP 제한을 해제하고 이전에 차단됐던 앱 NAT에서도 화면과 API를 익명으로 검증했다. 등록·조회·수정·변경값 재조회·삭제가 모두 성공했고 테스트 레코드는 제거했다. WEB/API 대상 그룹은 각각 노드 대상 2개 모두 healthy였다. 저장하는 애플리케이션 이미지는 비공개 ECR, 공개하는 것은 이 소스 저장소다. [EKS 권한·가용성 정책 및 검증표](EKS-POLICY.md).
