# Petclinic — 로컬 소스와 실행 방법

두 하위 폴더는 하나의 저장소에 포함된 Angular·Spring REST 앱입니다. 이 로컬 실행 절차는 AWS 리소스를 생성하거나 변경하지 않습니다.

| 폴더 | 원본 기준 커밋 | 역할 |
|---|---|---|
| `spring-petclinic-angular/` | `spring-petclinic/spring-petclinic-angular` · `8a0e199` | 브라우저 화면(`/`), 개발 서버 또는 Nginx |
| `spring-petclinic-rest/` | `spring-petclinic/spring-petclinic-rest` · `0515ec8` | Spring Boot API(`/petclinic/api/`, 기본 포트 `9966`) |

## 처음 실행: AWS나 PostgreSQL 없이

JDK 21과 Node.js 24.x(npm 포함)를 준비합니다. 아래 두 터미널은 각각 이 README가 있는 폴더에서 시작합니다.

**터미널 1 — REST**

```sh
cd spring-petclinic-rest
./mvnw spring-boot:run
```

기본 H2 DB에는 예제 데이터가 들어 있습니다. 메모리 DB이므로 앱을 종료하면 변경분은 사라집니다.

**터미널 2 — Angular**

```sh
cd spring-petclinic-angular
npm ci
npm start
```

브라우저에서 **http://localhost:4200/** 를 열어 `Owners` 목록을 확인하세요. 브라우저는 같은 주소의 `/petclinic/api/`를 호출하고 개발 서버가 REST의 `127.0.0.1:9966`으로 전달합니다. 관리 서버나 VPC 주소를 코드에 넣지 않습니다. 종료할 때는 두 터미널에서 각각 `Ctrl+C`를 누르세요.

```sh
# 직접 API와 개발 서버 경유 API가 모두 JSON 목록을 반환해야 합니다.
curl -fsS http://127.0.0.1:9966/petclinic/api/owners
curl -fsS http://localhost:4200/petclinic/api/owners
# 앱 상태 점검
curl -fsS http://127.0.0.1:9966/petclinic/actuator/health/readiness
```

## 선택: 기존 PostgreSQL 사용

REST 실행 환경에 `SPRING_PROFILES_ACTIVE=external-postgres`, `POSTGRES_URL`(JDBC URL), `POSTGRES_USER`, `POSTGRES_PASS`를 전달한 뒤 같은 Maven 명령을 실행합니다. 실제 비밀값은 저장소에 기록하지 마세요. 운영 DB는 서버 인증서 검증을 포함하는 TLS 연결을 사용하세요.

이 프로필은 테이블을 변경하거나 샘플 데이터를 넣지 않고 시작 시 스키마를 검증합니다. 새 빈 개발 DB를 쓰려면 먼저 `spring-petclinic-rest/src/main/resources/db/postgres/schema.sql`을 1회 적용하세요. `data.sql`은 샘플 데이터가 필요한 **일회용 개발 DB에서만** 선택적으로 적용합니다. 기존 운영 DB에 이 스크립트를 재실행하지 마세요.

## 나중에 EKS에서 사용할 때

프론트 컨테이너는 `8080`, REST는 `9966`을 사용합니다. 같은 호스트에서 `/petclinic/api`와 그 하위 경로는 REST로 **경로를 유지해서** 보내고 나머지 `/`는 Angular로 보냅니다. Angular의 로컬 개발 프록시는 프로덕션 Nginx에 포함되지 않으므로 이 라우팅은 별도로 필요합니다. 샘플은 기본적으로 API 인증이 꺼져 있으므로 그대로 인터넷에 공개하지 마세요. 이 작업에는 EKS/VPC/Ingress 생성이나 이미지 푸시가 포함되지 않습니다.
