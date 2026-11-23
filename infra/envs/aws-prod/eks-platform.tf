locals {
  platform_name = "petclinic-prod"
  eks_tags      = { project = "petclinic", environment = "prod", component = "app" }
  mgmt_tags     = { project = "petclinic", environment = "prod", component = "management" }
  ec2_trust = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role" "eks_control_plane" {
  name = "${local.platform_name}-eks-control-plane"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "eks.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = merge(local.eks_tags, { Name = "${local.platform_name}-eks-control-plane" })
}

resource "aws_iam_role_policy_attachment" "eks_control_plane" {
  role       = aws_iam_role.eks_control_plane.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_eks_cluster" "petclinic" {
  name     = local.platform_name
  role_arn = aws_iam_role.eks_control_plane.arn
  version  = "1.36"
  upgrade_policy { support_type = "STANDARD" }

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }
  vpc_config {
    subnet_ids              = module.network.app_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = false
  }
  tags       = merge(local.eks_tags, { Name = "${local.platform_name}-eks" })
  depends_on = [aws_iam_role_policy_attachment.eks_control_plane]
}

resource "aws_iam_role" "eks_node" {
  name               = "${local.platform_name}-eks-node"
  assume_role_policy = local.ec2_trust
  tags               = merge(local.eks_tags, { Name = "${local.platform_name}-eks-node" })
}

resource "aws_iam_role_policy_attachment" "eks_node" {
  for_each   = toset(["AmazonEKSWorkerNodePolicy", "AmazonEC2ContainerRegistryPullOnly"])
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/${each.key}"
}

# Only aws-node (not the EC2 role or ordinary pods) gets VPC CNI permissions.
locals {
  eks_oidc_issuer = aws_eks_cluster.petclinic.identity[0].oidc[0].issuer
  eks_oidc_host   = trimprefix(local.eks_oidc_issuer, "https://")
}

resource "aws_iam_openid_connect_provider" "eks" {
  url            = local.eks_oidc_issuer
  client_id_list = ["sts.amazonaws.com"]
  tags           = merge(local.eks_tags, { Name = "${local.platform_name}-eks-oidc" })
}

resource "aws_iam_role" "eks_cni" {
  name = "${local.platform_name}-eks-cni"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = aws_iam_openid_connect_provider.eks.arn }
      Condition = { StringEquals = {
        "${local.eks_oidc_host}:sub" = "system:serviceaccount:kube-system:aws-node"
        "${local.eks_oidc_host}:aud" = "sts.amazonaws.com"
      } }
    }]
  })
  tags = merge(local.eks_tags, { Name = "${local.platform_name}-eks-cni" })
}

resource "aws_iam_role_policy_attachment" "eks_cni" {
  role       = aws_iam_role.eks_cni.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.petclinic.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"
  service_account_role_arn    = aws_iam_role.eks_cni.arn
  tags                        = merge(local.eks_tags, { Name = "${local.platform_name}-vpc-cni" })
  depends_on                  = [aws_iam_role_policy_attachment.eks_cni]
}

# No custom SG: EKS attaches its cluster SG to every managed node. The default
# VPC CNI uses node ENI SGs for pod traffic (including pod -> RDS).
resource "aws_launch_template" "app_nodes" {
  name_prefix = "${local.platform_name}-app-"
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      encrypted             = true
      volume_size           = 20
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }
  dynamic "tag_specifications" {
    for_each = toset(["instance", "volume"])
    content {
      resource_type = tag_specifications.value
      tags          = merge(local.eks_tags, { Name = "${local.platform_name}-app-node" })
    }
  }
  tags = merge(local.eks_tags, { Name = "${local.platform_name}-app-template" })
}

resource "aws_eks_node_group" "app" {
  cluster_name    = aws_eks_cluster.petclinic.name
  node_group_name = "${local.platform_name}-app"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = module.network.app_subnet_ids
  version         = aws_eks_cluster.petclinic.version
  ami_type        = "AL2023_x86_64_STANDARD"
  instance_types  = ["t3.medium"]
  capacity_type   = "ON_DEMAND"
  scaling_config {
    min_size     = 2
    desired_size = 2
    max_size     = 2
  }
  launch_template {
    id      = aws_launch_template.app_nodes.id
    version = aws_launch_template.app_nodes.latest_version
  }
  update_config { max_unavailable = 1 }
  tags       = merge(local.eks_tags, { Name = "${local.platform_name}-app-nodes" })
  depends_on = [aws_iam_role_policy_attachment.eks_node, aws_eks_addon.vpc_cni]
}

resource "aws_security_group" "management" {
  name_prefix = "${local.platform_name}-management-"
  description = "SSM managed host; no inbound access"
  vpc_id      = module.network.management_vpc_id
  tags        = merge(local.mgmt_tags, { Name = "${local.platform_name}-management-sg" })
}

resource "aws_security_group" "management_endpoints" {
  name_prefix = "${local.platform_name}-endpoints-"
  description = "Private management AWS API endpoints"
  vpc_id      = module.network.management_vpc_id
  tags        = merge(local.mgmt_tags, { Name = "${local.platform_name}-endpoints-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "management_endpoints" {
  security_group_id            = aws_security_group.management_endpoints.id
  referenced_security_group_id = aws_security_group.management.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  tags                         = merge(local.mgmt_tags, { Name = "${local.platform_name}-endpoint-from-management" })
}

resource "aws_vpc_security_group_egress_rule" "management_endpoints" {
  security_group_id            = aws_security_group.management.id
  referenced_security_group_id = aws_security_group.management_endpoints.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  tags                         = merge(local.mgmt_tags, { Name = "${local.platform_name}-management-to-endpoints" })
}

# PrivateLink serves the AWS EKS management API, NOT the Kubernetes API.
resource "aws_vpc_endpoint" "management" {
  for_each            = toset(["ssm", "ssmmessages", "eks", "sts"])
  vpc_id              = module.network.management_vpc_id
  vpc_endpoint_type   = "Interface"
  service_name        = "com.amazonaws.${var.aws_region}.${each.key}"
  private_dns_enabled = true
  subnet_ids          = [module.network.management_subnet_id]
  security_group_ids  = [aws_security_group.management_endpoints.id]
  tags                = merge(local.mgmt_tags, { Name = "${local.platform_name}-management-${each.key}" })
}

resource "aws_vpc_security_group_egress_rule" "management_api" {
  security_group_id            = aws_security_group.management.id
  referenced_security_group_id = aws_eks_cluster.petclinic.vpc_config[0].cluster_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  tags                         = merge(local.mgmt_tags, { Name = "${local.platform_name}-management-to-eks" })
}

resource "aws_vpc_security_group_ingress_rule" "management_api" {
  security_group_id            = aws_eks_cluster.petclinic.vpc_config[0].cluster_security_group_id
  referenced_security_group_id = aws_security_group.management.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  tags                         = merge(local.eks_tags, { Name = "${local.platform_name}-eks-from-management" })
}

resource "aws_iam_role" "management" {
  name               = "${local.platform_name}-management"
  assume_role_policy = local.ec2_trust
  tags               = merge(local.mgmt_tags, { Name = "${local.platform_name}-management-role" })
}

resource "aws_iam_role_policy" "management" {
  name = "session-agent-and-cluster-discovery"
  role = aws_iam_role.management.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = "eks:DescribeCluster", Resource = aws_eks_cluster.petclinic.arn },
      { Effect = "Allow", Action = [
        "ssm:UpdateInstanceInformation", "ssmmessages:CreateControlChannel", "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel", "ssmmessages:OpenDataChannel"
      ], Resource = "*" }
    ]
  })
}

resource "aws_eks_access_entry" "management" {
  cluster_name  = aws_eks_cluster.petclinic.name
  principal_arn = aws_iam_role.management.arn
  type          = "STANDARD"
  tags          = merge(local.mgmt_tags, { Name = "${local.platform_name}-management-access" })
}

resource "aws_eks_access_policy_association" "management" {
  cluster_name  = aws_eks_access_entry.management.cluster_name
  principal_arn = aws_eks_access_entry.management.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"
  access_scope {
    type       = "namespace"
    namespaces = ["petclinic"]
  }
}

resource "aws_iam_instance_profile" "management" {
  name = "${local.platform_name}-management"
  role = aws_iam_role.management.name
  tags = merge(local.mgmt_tags, { Name = "${local.platform_name}-management-profile" })
}

data "aws_ssm_parameter" "management_al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_instance" "management" {
  ami                         = data.aws_ssm_parameter.management_al2023.value
  instance_type               = "t3.micro"
  subnet_id                   = module.network.management_subnet_id
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.management.id]
  iam_instance_profile        = aws_iam_instance_profile.management.name
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
  root_block_device {
    encrypted   = true
    volume_type = "gp3"
  }
  volume_tags = merge(local.mgmt_tags, { Name = "${local.platform_name}-management-root" })
  tags        = merge(local.mgmt_tags, { Name = "${local.platform_name}-management" })
  depends_on = [
    aws_iam_role_policy.management, aws_vpc_endpoint.management,
    aws_vpc_security_group_ingress_rule.management_endpoints, aws_vpc_security_group_egress_rule.management_endpoints
  ]
}
