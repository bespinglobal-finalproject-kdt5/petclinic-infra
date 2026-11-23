locals {
  platform_name = "petclinic-prod"
  eks_tags      = { project = "petclinic", environment = "prod", component = "app" }
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

# No extra EKS management ingress until the Seoul management host and its private path exist.
# Osaka is for observability and must not be granted control-plane access.
