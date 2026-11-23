terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
  }
}

resource "aws_iam_role" "eks_control_plane" {
  name = "${var.name}-eks-control-plane"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "eks.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = merge(var.tags, { Name = "${var.name}-eks-control-plane" })
}

resource "aws_iam_role_policy_attachment" "eks_control_plane" {
  role       = aws_iam_role.eks_control_plane.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_eks_cluster" "petclinic" {
  name     = var.name
  role_arn = aws_iam_role.eks_control_plane.arn
  version  = var.kubernetes_version
  upgrade_policy { support_type = "STANDARD" }

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }
  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = false
  }
  tags       = merge(var.tags, { Name = "${var.name}-eks" })
  depends_on = [aws_iam_role_policy_attachment.eks_control_plane]
}
