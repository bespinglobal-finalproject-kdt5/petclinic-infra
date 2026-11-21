# Petclinic EKS 앱

Angular 화면과 Spring Boot REST API를 한 저장소에 모은 배포용 소스입니다. 브라우저는 같은 도메인의 `/petclinic/api/`를 호출합니다. 앱 코드를 공개하는 것과 데모 사이트를 인터넷 전체에 공개하는 것은 별개입니다.

- [소스 변경과 WEB·WAS·DB 서브넷 배치](docs/DEPLOYMENT-LAYOUT.md): 서울 리전에 배포된 웹/API Pod의 실제 AZ 및 PostgreSQL 배치를 설명합니다.
- [로컬 실행](LOCAL.md): Node.js 24, JDK 21. 기본 DB는 개발용 메모리 H2입니다.
- [EKS 설정·보안·가용성 정책](docs/EKS-POLICY.md): 적용한 설정값, 선택 이유, 제한, 실제 서비스 검증 결과를 설명합니다.
- [Pod와 Service 매니페스트 템플릿](deploy/k8s/apps.yaml.in): DB 호스트와 웹/API 이미지 digest를 렌더링해 사용합니다. 이미 준비된 `petclinic` 네임스페이스, `rds-ca` ConfigMap, 앱 계정 Secret이 필요합니다. 템플릿만으로 AWS 인프라가 생성되지는 않습니다.
- 인프라 코드와 운영 절차는 [petclinic-infra](https://github.com/bespinglobal-finalproject-kdt5/petclinic-infra)에서 별도로 관리합니다. 이 저장소는 운영 AWS 접근 권한을 포함하지 않습니다.

공개 데모: **https://mission-critical.site**. IP 제한이나 로그인 없이 누구나 데이터를 조회·등록·수정·삭제할 수 있습니다. **실제 이름, 주소, 전화번호 대신 가상 데이터만 입력하세요.** WEB/API 이미지는 비공개 AWS ECR에서 가져옵니다.

## 소스 출처

| 구성 | 기반 소스 | 변경 사항 |
|---|---|---|
| [Angular](spring-petclinic-angular/README.md) | [spring-petclinic-angular, 8a0e199](https://github.com/spring-petclinic/spring-petclinic-angular/tree/8a0e199) | 동일 출처 API, 로컬 개발 프록시, 루트 경로 SPA, non-root Nginx 이미지 |
| [Spring REST](spring-petclinic-rest/readme.md) | [spring-petclinic-rest, 0515ec8](https://github.com/spring-petclinic/spring-petclinic-rest/tree/0515ec8) | 외부 PostgreSQL 프로필, 상태 검사, non-root Java 21 런타임 이미지 |

각 소스의 기존 라이선스 및 저작권 고지를 유지합니다([REST 라이선스](spring-petclinic-rest/LICENSE.txt)). 외부 프로젝트의 릴리스·자동 병합 워크플로는 이 저장소로 복사하지 않았습니다.
