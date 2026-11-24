# AWS 운영 서브넷과 EKS 연결 규칙

**EKS가 사용할 네트워크는 서울 서비스 VPC의 `app_1`과 `app_2`다.** EKS 담당자는 `aws-prod`의 `service_vpc_id`와 `app_subnet_ids`를 받아 클러스터·워커에 사용한다. 운영 Terraform 루트가 내부 ALB를 같은 앱 서브넷에 배치한다. 서브넷, 태그, 라우팅 테이블의 소유자는 이 저장소의 네트워크 모듈이다. [운영 루트](main.tf) · [루트 출력](outputs.tf)

서울 서비스 VPC와 관리 VPC의 Terraform 구성 기준이다. 서울 AZ와 운영 계정 ID는 루트 입력으로 지정한다. Azure DR용으로 `10.30.0.0/24`를 예약했다. [입력 검증](variables.tf) · [provider 설정](providers.tf) · [공통 네트워크 설계](../../NETWORK.md)

## 서브넷 8개

모든 행에 `project=petclinic`, `environment=prod`가 적용된다. **공인 IPv4** 열은 EC2 시작 시 자동 할당 여부인 `map_public_ip_on_launch`다. **경로** 열은 아래 라우팅 표의 행과 대응한다.

| Terraform 키 | IPv4 CIDR | AZ | 공인 IPv4 | `component` | AWS `Name` 태그 | 경로 |
|---|---|---|---|---|---|---|
| `app_1` | `10.10.0.0/24` | 서울 2a | `false` | `app` | `petclinic-prod-app-subnet-2a` | 서울 앱 |
| `app_2` | `10.10.1.0/24` | 서울 2c | `false` | `app` | `petclinic-prod-app-subnet-2c` | 서울 앱 |
| `public_1` | `10.10.2.0/27` | 서울 2a | `false` | `network` | `petclinic-prod-public-subnet-2a` | 서울 퍼블릭 |
| `public_2` | `10.10.2.32/27` | 서울 2c | `false` | `network` | `petclinic-prod-public-subnet-2c` | 서울 퍼블릭 |
| `db_1` | `10.10.2.64/27` | 서울 2a | `false` | `database` | `petclinic-prod-db-subnet-2a` | 서울 DB |
| `db_2` | `10.10.2.96/27` | 서울 2c | `false` | `database` | `petclinic-prod-db-subnet-2c` | 서울 DB |
| `management` | `10.20.0.0/27` | 서울 2a | `false` | `management` | `petclinic-prod-management-subnet-2a` | 서울 관리 |
| `management_public` | `10.20.0.32/27` | 서울 2a | `false` | `management` | `petclinic-prod-management-public-subnet-2a` | 서울 빌드 |

서울 서비스 서브넷 6개의 Terraform 주소 형식은 `module.seoul_vpc1.aws_subnet.service["app_1"]`이다. 서울 관리 VPC의 서브넷 주소는 `module.seoul_vpc2.aws_subnet.management`와 `module.seoul_vpc2.aws_subnet.management_public`다. 운영 루트는 서울 서비스 VPC와 관리 VPC를 별도 모듈로 호출한다. [서울 서브넷](seoul-vpc1-service/subnets.tf) · [서울 관리 서브넷](seoul-vpc2-management/main.tf)

## 태그와 이름 생성식

| 키 | 값과 작성 규칙 |
|---|---|
| `project` | 프로젝트 식별값은 소문자 `petclinic`이다. |
| `environment` | AWS 운영 루트는 `prod`를 넘긴다. 서울 서비스 모듈이 허용하는 값은 `prod`, `azure_dr` 두 개다. 디렉터리 이름 `aws-prod`, `azure-dr`와 태그 값의 표기가 다르다. |
| `component` | 팀 공통 분류는 `network`, `app`, `database`, `management`, `monitoring`이다. EKS 워크로드의 분류는 `app`, RDS는 `database`다. 현재 서브넷에는 앞 표의 네 값이 쓰인다. |
| `Name` | 대문자 `N`을 사용한다. 서울의 형식은 `petclinic-<environment>-<역할>-subnet-<AZ 접미사>`다. 역할은 `app`, `public`, `db`, `management`, `management-public`이다. 예를 들어 `db_2`의 역할은 `db`, `component`는 `database`, AZ 접미사는 `2c`다. |

서비스 VPC는 공통 태그에 리소스별 `component`와 `Name`을 더한다. 관리 VPC는 공통 태그에 `component=management`를 포함하고 리소스마다 `Name`을 지정한다. 서비스 서브넷의 역할은 키에서 첫 `_` 앞의 문자열, AZ 접미사는 전체 AZ 이름에서 마지막 `-` 뒤의 문자열이다. `_1`은 `availability_zones[0]`, `_2`는 `[1]`을 선택한다. 운영 입력은 `["ap-northeast-2a", "ap-northeast-2c"]`이며, 루트는 서울 리전의 서로 다른 표준 AZ 두 개를 요구한다. 순서를 바꾸면 같은 키가 가리키는 AZ와 생성되는 이름이 달라진다. [생성식](seoul-vpc1-service/subnets.tf) · [모듈 입력](seoul-vpc1-service/variables.tf) · [팀 태그 사전](../../TAGS.md)

EKS 담당자는 클러스터와 노드 그룹의 `tags`에 `project = "petclinic"`, `environment = "prod"`, `component = "app"`을 공통으로 넣고, `Name`은 자원별로 부여한다. 예를 들어 클러스터의 `Name`은 `petclinic-prod-eks-cluster`로 지을 수 있다. 실제 클러스터 이름과 노드 그룹 이름은 EKS 코드에서 정한다. [팀 태그 사전](../../TAGS.md) · [운영 루트의 모듈 구성](main.tf)

## VPC, 라우팅과 주소 할당

| 경로 | 부모 VPC와 로컬 대역 | 라우팅 테이블 | 추가 경로 |
|---|---|---|---|
| 서울 앱 | `petclinic-prod-service-vpc` · `10.10.0.0/22` | `service_app` · `petclinic-prod-app-rtb` | `0.0.0.0/0` → `petclinic-prod-nat-2a`, `10.20.0.0/24` → 서울 관리 VPC 피어링 |
| 서울 퍼블릭 | `petclinic-prod-service-vpc` · `10.10.0.0/22` | `service_public` · `petclinic-prod-public-rtb` | `0.0.0.0/0` → `petclinic-prod-service-igw` |
| 서울 DB | `petclinic-prod-service-vpc` · `10.10.0.0/22` | `service_private` · `petclinic-prod-db-rtb` | 로컬만 사용. 코드에서 `route = []` 지정 |
| 서울 관리 | `petclinic-prod-management-vpc` · `10.20.0.0/24` | `management` · `petclinic-prod-management-rtb` | `0.0.0.0/0` → 관리 NAT, `10.10.0.0/22` → 서울 서비스 VPC 피어링 |
| 서울 빌드 | `petclinic-prod-management-vpc` · `10.20.0.0/24` | `management_public` · `petclinic-prod-management-public-rtb` | `0.0.0.0/0` → `petclinic-prod-management-igw` |

- 각 행에서 부모 VPC CIDR의 목적지는 AWS의 `local` 경로다. 서울은 서비스 서브넷별 `aws_route_table_association.service`와 관리 VPC의 `aws_route_table_association.management`·`aws_route_table_association.management_public`으로 테이블을 명시한다. 피어링 경로는 서울 VPC 1의 앱 테이블과 서울 VPC 2의 프라이빗 테이블에 있다. [서울 연결 정의](seoul-vpc1-service/subnets.tf) · [서울 관리 라우팅](seoul-vpc2-management/main.tf)
- 서울 서비스 VPC의 퍼블릭 서브넷 두 개에는 IGW 경로가 있지만 공인 IPv4 자동 할당은 꺼져 있다. 두 앱 서브넷은 모두 `public_1`에 있는 단일 zonal public NAT와 VPC EIP `petclinic-prod-nat-eip`를 통해 송신한다. 2c의 앱도 2a NAT에 의존한다. [서울 NAT·IGW](seoul-vpc1-service/main.tf)
- 서울 관리 퍼블릭 서브넷도 공인 IPv4 자동 할당을 끄고, 빌드 EC2에만 공인 IPv4를 할당한다. 프라이빗 서브넷의 기본 경로는 관리 NAT를 사용한다. 관리 서버의 SSM 트래픽은 이 서브넷 안의 두 인터페이스 엔드포인트로 향한다. [관리 서버 연결](seoul-vpc2-management/management-server/ssm-endpoints.tf) [관리 퍼블릭 라우팅](seoul-vpc2-management/main.tf) · [빌드 EC2](seoul-vpc2-management/build-server/main.tf)
- 서비스 VPC는 `enable_dns_support = true`, `enable_dns_hostnames = true`를 명시한다. 서브넷은 고정 IPv4 CIDR을 사용하고 IPv6 CIDR·IPv6 자동 할당·DNS64·서브넷별 DNS 호스트 이름 옵션은 코드에서 따로 설정하지 않는다. 커스텀 네트워크 ACL·ACL 연결도 정의하지 않는다. 내부 ALB의 보안 그룹과 443 리스너는 운영 Terraform 루트가 관리한다. [네트워크 정의](seoul-vpc1-service/main.tf) · [EKS 연결 절차](README.md)
- AWS 예약 IPv4 5개를 제외한 서브넷당 할당 가능 주소는 `/24`에서 251개, `/27`에서 27개다. 배포 시 실제 여유량은 `AvailableIpAddressCount`로 확인한다. ALB에 쓰는 **두 앱 서브넷 각각**에 최소 8개의 빈 IPv4 주소가 필요하다. [AWS 서브넷 주소 규칙](https://docs.aws.amazon.com/vpc/latest/userguide/subnet-sizing.html) · [ALB 서브넷 요건](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/application-load-balancers.html#subnets-load-balancer)

## EKS 담당자가 코드에서 사용할 값

| 운영 루트 출력 | 값의 의미와 순서 |
|---|---|
| `service_vpc_id`, `app_subnet_ids` | 서울 서비스 VPC ID와 `[app_1, app_2]`. 클러스터의 `vpc_config.subnet_ids`, 관리형 노드 그룹의 `subnet_ids`, 내부 ALB의 서브넷 선택에 같은 앱 서브넷 쌍을 사용한다. |
| `public_subnet_ids`, `db_subnet_ids` | 각각 `[public_1, public_2]`, `[db_1, db_2]`. 퍼블릭 경로와 DB 서브넷 그룹에 쓰는 별도 목록이다. |
| `management_vpc_id`, `management_subnet_id`, `management_public_subnet_id` | 서울 관리 VPC, 기존 프라이빗 서브넷, 빌드용 퍼블릭 서브넷의 ID다. |

같은 Terraform 루트에서 EKS 모듈을 호출할 때는 `module.seoul_vpc1.service_vpc_id`, `module.seoul_vpc1.app_subnet_ids`를 입력으로 연결한다. 다른 작업 디렉터리에서는 운영 루트의 출력을 전달받는다. 아래 조회 명령은 저장소 루트에서 실행하며, 마지막 줄은 공유할 서브넷 ID를 쉼표로 구분해 출력한다. [네트워크 모듈 출력](seoul-vpc1-service/outputs.tf) · [운영 루트 출력](outputs.tf)

```sh
terraform -chdir=infra/envs/aws-prod output -raw service_vpc_id
terraform -chdir=infra/envs/aws-prod output -json app_subnet_ids
terraform -chdir=infra/envs/aws-prod output -json app_subnet_ids | jq -r 'join(",")'
```

운영 Terraform 루트는 `app_subnet_ids`로 내부 ALB의 두 서브넷을 직접 지정한다. `seoul_internal_alb` 출력에서 기존 ALB 및 리스너 ARN을 조회할 수 있다. 리스너는 서울 ACM 인증서로 HTTPS 443을 받고, 앱 대상 그룹 연결 전에는 고정 응답 503을 반환한다. CloudFront 오리진 연결과 앱 대상 등록은 후속 작업이다. [내부 ALB 정의](internal-alb.tf) · [운영 루트 출력](outputs.tf)

현재 서브넷 코드에는 `kubernetes.io/role/internal-elb`, `kubernetes.io/role/elb`, `kubernetes.io/cluster/<cluster-name>` 태그가 없다. 아래 Ingress 예시는 컨트롤러로 별도 ALB를 생성하는 경우의 참고용이다. 운영 ALB는 위 Terraform 리소스가 관리한다. `var.app_subnet_ids`에는 위 목록을 넣는다. ALB의 공통 태그는 컨트롤러가 생성하는 AWS 자원에 적용된다. [EKS의 ALB 서브넷 선택](https://docs.aws.amazon.com/eks/latest/userguide/alb-ingress.html) · [컨트롤러 어노테이션](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/ingress/annotations/)

```hcl
locals {
  ingress_annotations = {
    "alb.ingress.kubernetes.io/scheme"          = "internal"
    "alb.ingress.kubernetes.io/subnets"         = join(",", var.app_subnet_ids)
    "alb.ingress.kubernetes.io/additional-tags" = "project=petclinic,environment=prod,component=app"
  }
}
```
