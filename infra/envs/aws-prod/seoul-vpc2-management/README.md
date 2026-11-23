# 서울 관리 VPC 2

- 관리 VPC 2(`10.20.0.0/24`)는 서울 2a 서브넷 두 개를 관리한다. 기존 프라이빗 `10.20.0.0/27`은 로컬 경로만 사용한다. 빌드용 퍼블릭 `10.20.0.32/27`에는 전용 라우팅 테이블의 `0.0.0.0/0`이 관리 IGW로 연결된다. [퍼블릭 서브넷과 라우팅](main.tf)
- 루트 출력은 `management_vpc_id`, `management_subnet_id`(프라이빗), `management_public_subnet_id`(빌드용)다. 빌드 EC2와 SSM 역할은 [빌드 서버 모듈](build-server/)에서 관리한다.
- 오사카 관제망(`10.40.0.0/16`)은 `osaka_observe`로 조회한다. [오사카 관제망](../OSAKA-VPC2.md)
