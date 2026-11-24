resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 7
}

resource "aws_eks_cluster" "this" {
  name                          = var.cluster_name
  version                       = var.kubernetes_version
  role_arn                      = aws_iam_role.cluster.arn
  bootstrap_self_managed_addons = false
  enabled_cluster_log_types     = ["api", "audit", "authenticator"]

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = false
  }
  vpc_config {
    subnet_ids              = module.seoul_vpc1.app_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = false
  }
  kubernetes_network_config {
    ip_family         = "ipv4"
    service_ipv4_cidr = "172.20.0.0/16"
  }

  lifecycle {
    precondition {
      condition     = alltrue([for subnet in data.aws_subnet.private : subnet.vpc_id == module.seoul_vpc1.service_vpc_id])
      error_message = "All private subnets must belong to the existing service VPC."
    }
    precondition {
      condition     = length(toset([for subnet in data.aws_subnet.private : subnet.availability_zone])) >= 2
      error_message = "The existing app subnets must span at least two AZs."
    }
    precondition {
      condition     = data.aws_vpc.service.enable_dns_support && data.aws_vpc.service.enable_dns_hostnames
      error_message = "Private EKS API requires DNS support and DNS hostnames on the existing service VPC."
    }
  }

  depends_on = [aws_iam_role_policy_attachment.cluster, aws_cloudwatch_log_group.cluster]
}

resource "aws_vpc_security_group_ingress_rule" "management_api" {
  security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  description       = "Private API from the existing management EC2 over peering"
  cidr_ipv4         = "${module.seoul_vpc2.management_private_ip}/32"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_eks_access_entry" "admin" {
  for_each      = local.cluster_admins
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admin" {
  for_each      = local.cluster_admins
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope {
    type = "cluster"
  }
  depends_on = [aws_eks_access_entry.admin]
}
