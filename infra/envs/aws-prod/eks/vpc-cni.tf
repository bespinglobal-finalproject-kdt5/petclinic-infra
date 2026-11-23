# Only aws-node (not the EC2 role or ordinary pods) gets VPC CNI permissions.
locals {
  eks_oidc_issuer = aws_eks_cluster.petclinic.identity[0].oidc[0].issuer
  eks_oidc_host   = trimprefix(local.eks_oidc_issuer, "https://")
}

resource "aws_iam_openid_connect_provider" "eks" {
  url            = local.eks_oidc_issuer
  client_id_list = ["sts.amazonaws.com"]
  tags           = merge(var.tags, { Name = "${var.name}-eks-oidc" })
}

resource "aws_iam_role" "eks_cni" {
  name = "${var.name}-eks-cni"
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
  tags = merge(var.tags, { Name = "${var.name}-eks-cni" })
}

resource "aws_iam_role_policy_attachment" "eks_cni" {
  role       = aws_iam_role.eks_cni.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.petclinic.name
  addon_name                  = "vpc-cni"
  addon_version               = var.vpc_cni_version
  resolve_conflicts_on_create = "OVERWRITE"
  service_account_role_arn    = aws_iam_role.eks_cni.arn
  tags                        = merge(var.tags, { Name = "${var.name}-vpc-cni" })
  depends_on                  = [aws_iam_role_policy_attachment.eks_cni]
}
