mock_provider "aws" {}
mock_provider "tls" {}

run "private_cluster_and_admin_access" {
  command = plan
  module { source = "./eks" }

  variables {
    aws_account_id       = "123456789012"
    aws_region           = "ap-northeast-2"
    cluster_name         = "petclinic-test-eks"
    service_vpc_id       = "vpc-00000000000000001"
    app_subnet_ids       = ["subnet-00000000000000001", "subnet-00000000000000002"]
    kubernetes_version   = "1.36"
    node_instance_type   = "t3.medium"
    node_scaling         = { min = 2, desired = 2, max = 4 }
    node_release_version = "1.36.0-20260101"
    addon_versions = {
      vpc-cni        = "v1.0.0-eksbuild.1"
      coredns        = "v1.0.0-eksbuild.1"
      kube-proxy     = "v1.36.0-eksbuild.1"
      metrics-server = "v0.1.0-eksbuild.1"
    }
    cluster_admins = {
      "arn:aws:iam::123456789012:role/mock-admin" = "arn:aws:iam::123456789012:role/mock-admin"
    }
  }

  override_data {
    target = data.aws_vpc.service
    values = { enable_dns_support = true, enable_dns_hostnames = true }
  }

  override_data {
    target = data.aws_subnet.private["app_1"]
    values = { vpc_id = "vpc-00000000000000001", availability_zone = "ap-northeast-2a" }
  }

  override_data {
    target = data.aws_subnet.private["app_2"]
    values = { vpc_id = "vpc-00000000000000001", availability_zone = "ap-northeast-2c" }
  }

  assert {
    condition = (
      toset(keys(data.aws_subnet.private)) == toset(["app_1", "app_2"]) &&
      aws_eks_cluster.this.vpc_config[0].subnet_ids == toset(var.app_subnet_ids) &&
      aws_eks_cluster.this.vpc_config[0].endpoint_private_access && !aws_eks_cluster.this.vpc_config[0].endpoint_public_access
    )
    error_message = "The EKS API must be private and use both app subnets."
  }

  assert {
    condition = (
      toset(keys(aws_eks_access_entry.admin)) == toset(keys(var.cluster_admins)) &&
      toset(keys(aws_eks_access_policy_association.admin)) == toset(keys(var.cluster_admins)) &&
      alltrue([for key, arn in var.cluster_admins :
        aws_eks_access_entry.admin[key].principal_arn == arn && aws_eks_access_policy_association.admin[key].principal_arn == arn
      ])
    )
    error_message = "Each configured administrator must have a matching EKS access entry and policy association."
  }
}
