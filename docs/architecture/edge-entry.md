# Petclinic edge entry

Historical design for the former Terraform-managed ALB. The current handoff to the EKS-managed Ingress is described in the [AWS production environment](../../infra/envs/aws-prod/README.md).

[Open the editable diagram](edge-entry.drawio) in diagrams.net. **Status: proposed, not live-verified.** The existing `mission-critical.site` zone, Seoul network and Osaka state backend are inputs to this design. The repository defines the network layout; it does not establish that the proposed edge resources are running.

## Follow one request

1. **Resolve the viewer name.** The browser's DNS resolver queries the existing Route 53 public zone. A proposed alias for the chosen viewer hostname resolves to CloudFront, not to the ALB. Route 53 does not proxy HTTP.
2. **Connect over HTTPS.** The browser connects to CloudFront on port 443. CloudFront presents an ACM viewer certificate covering that hostname. The certificate must be in `us-east-1`; its DNS-validation CNAME in Route 53 is distinct from the viewer alias. Keep the validation record for renewal.
3. **Reach the private origin.** When CloudFront needs the origin, it uses a CloudFront VPC origin over **HTTP:80** to one **internal** Application Load Balancer in Seoul (`ap-northeast-2`). Viewer TLS terminates at CloudFront; this design does not claim end-to-end TLS. The ALB spans `app_1` and `app_2`, not the public subnets. Its security group should admit origin traffic on port 80 only from the intended CloudFront VPC origin source.
4. **Return a fixed response.** The ALB listener matches the exact path `/health` and returns **200**. Its default action returns **404**, including for `/`. Neither action forwards to a target group. A successful `/health` request tests the entry path, not an application, pod or EKS cluster. A cached response alone does not prove current origin reachability.

In the diagram, solid arrows trace the request; dashed arrows show DNS and certificate relationships. The lower section has no inbound connectors by design.

## Seoul network inventory

The Seoul service VPC module defines the [subnet CIDRs](../../infra/envs/aws-prod/seoul-vpc1-service/subnets.tf) and [routing tables](../../infra/envs/aws-prod/seoul-vpc1-service/main.tf). The AZ names below assume environment inputs ordered `ap-northeast-2a`, then `ap-northeast-2c`. This proposal uses the two **private app** subnets even though the [network guide](../../infra/NETWORK.md) also describes a public pair sized for an ALB.

| VPC (CIDR) | Subnet | AZ | CIDR | Role here |
|---|---|---|---|---|
| Service (`10.10.0.0/22`) | `app_1` | 2a | `10.10.0.0/24` | Internal ALB placement |
| Service | `app_2` | 2c | `10.10.1.0/24` | Internal ALB placement |
| Service | `public_1` | 2a | `10.10.2.0/27` | Zonal public NAT gateway |
| Service | `public_2` | 2c | `10.10.2.32/27` | Public subnet; no origin |
| Service | `db_1` | 2a | `10.10.2.64/27` | Local routing only |
| Service | `db_2` | 2c | `10.10.2.96/27` | Local routing only |
| Management (`10.20.0.0/24`) | `management` | 2a | `10.20.0.0/27` | Local routing only; not an ingress hop |

**Outbound only:** both app subnets send their default route to the NAT gateway in `public_1`; its public subnet routes to the service VPC internet gateway. Neither gateway forwards browser requests to the ALB. **Separate state backend:** Amazon S3 in Seoul (`ap-northeast-2`) stores the active [Terraform state](../../infra/STATE.md); it is not a distribution origin.

## Evidence needed before marking the edge verified

- Confirm the public zone delegation, viewer alias target, CloudFront alternate domain name, and matching `ISSUED` ACM certificate in `us-east-1`.
- Confirm the distribution's deployed VPC origin references the internal ALB in the two listed app subnets. Check the origin protocol, port, allowed source and both listener actions.
- From the viewer hostname, check TLS, `/health` → `200`, and `/` → `404`. Use uncached responses or corroborate with origin logs to distinguish listener behavior from an edge cache hit. No live checks are claimed here.
