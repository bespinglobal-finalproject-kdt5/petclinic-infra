# 서울 관리 VPC 2

- 관리 VPC 2(`10.20.0.0/24`)는 서울 2a 서브넷 두 개를 관리한다. 기존 프라이빗 `10.20.0.0/27`은 로컬 경로만 사용한다. 빌드용 퍼블릭 `10.20.0.32/27`에는 전용 라우팅 테이블의 `0.0.0.0/0`이 관리 IGW로 연결된다. [퍼블릭 서브넷과 라우팅](main.tf)
- 루트 출력은 `management_vpc_id`, `management_subnet_id`(프라이빗), `management_public_subnet_id`(빌드용)다. 빌드 EC2와 SSM 역할은 [빌드 서버 모듈](build-server/)에서 관리한다.
- 오사카 관제망(`10.40.0.0/16`)은 `osaka_observe`로 조회한다. [오사카 관제망](../OSAKA-VPC2.md)

## 프라이빗 관리 서버

`management-server/` 모듈은 서울 2a의 `10.20.0.0/27`에 Ubuntu 24.04 LTS x86_64 온디맨드 `t3.small`(2 vCPU, 2 GiB)과 암호화된 gp3 루트 디스크 30 GiB를 정의한다. 인스턴스에는 공인 IP와 SSH 인바운드 규칙이 없다. 전용 IAM 인스턴스 프로필은 `AmazonSSMManagedInstanceCore`를 사용한다. [EC2 구성](management-server/main.tf)

관리 서버는 TCP 443으로 같은 서브넷의 `ssm`·`ssmmessages` 인터페이스 엔드포인트에 연결한다. 프라이빗 DNS 이름은 VPC 전체에서 해석되므로 엔드포인트 보안 그룹은 기존 빌드 서버 보안 그룹에서도 HTTPS를 허용한다. 두 엔드포인트는 관리 EC2를 중지해도 유지된다. [엔드포인트 구성](management-server/ssm-endpoints.tf) · [AWS Systems Manager 연결 요건](https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-create-vpc.html)

운영 적용 후 Session Manager 권한이 있는 프로필로 저장소 루트에서 접속한다.

```sh
instance_id=$(terraform -chdir=infra/envs/aws-prod output -raw management_instance_id)
aws ssm start-session --profile default --region ap-northeast-2 --target "$instance_id"
```
