# 관리 접속 경로

관리 호스트는 서울 레거시 `10.20.0.0/24`가 아니라 [오사카 관제 VM](../../envs/aws-prod/OSAKA-VPC2.md)이다. 이 모듈은 서울 서비스망과 앱 라우트 테이블을 관리한다. 운영 루트의 `management_vpc_id`와 `management_subnet_id`는 오사카를 가리킨다. `retire_seoul_management_vpc`는 기본값 `true`로 유지한다.

- 서울 앱 서브넷 두 곳에서 오사카 관제 서브넷으로만 피어 경로가 있다. 서울의 NAT 기본 경로는 바뀌지 않고 서울 DB·퍼블릭 서브넷은 피어 경로를 사용하지 않는다.
- 운영자는 `ap-northeast-3`의 Session Manager로 오사카 호스트에 접속한다. 호스트의 IAM 역할은 SSM 에이전트용이며 EKS 관리자 역할이 아니다.
- 서울 EKS가 다시 배포되는 경우, 운영자 PC에서 [터널 스크립트](../../../deploy/eks-tunnel.sh)를 실행한다. AWS CLI의 EKS 조회/인증은 서울(`AWS_REGION=ap-northeast-2`), SSM 포워딩은 오사카(`MANAGER_REGION=ap-northeast-3`)를 사용한다. EC2 사설 IP `/32`에서만 서울 EKS SG로 TCP/443을 허용하는 규칙이 EKS와 함께 생성된다. 터널은 EKS CA와 실제 API 서버 이름을 검증하며, 접근 권한은 별도로 허용된 운영자 IAM 신원에 따른다. EKS를 롤백한 상태에서는 `kubectl` 접속 대상이 없다.
