# EKS resources previously managed by the production root.
moved {
  from = data.aws_vpc.service
  to   = module.eks.data.aws_vpc.service
}

moved {
  from = data.aws_subnet.private
  to   = module.eks.data.aws_subnet.private
}

moved {
  from = aws_iam_role.cluster
  to   = module.eks.aws_iam_role.cluster
}

moved {
  from = aws_iam_role_policy_attachment.cluster
  to   = module.eks.aws_iam_role_policy_attachment.cluster
}

moved {
  from = aws_iam_role.node
  to   = module.eks.aws_iam_role.node
}

moved {
  from = aws_iam_role_policy_attachment.node
  to   = module.eks.aws_iam_role_policy_attachment.node
}

moved {
  from = aws_cloudwatch_log_group.cluster
  to   = module.eks.aws_cloudwatch_log_group.cluster
}

moved {
  from = aws_eks_cluster.this
  to   = module.eks.aws_eks_cluster.this
}

moved {
  from = aws_eks_access_entry.admin
  to   = module.eks.aws_eks_access_entry.admin
}

moved {
  from = aws_eks_access_policy_association.admin
  to   = module.eks.aws_eks_access_policy_association.admin
}

moved {
  from = aws_launch_template.node
  to   = module.eks.aws_launch_template.node
}

moved {
  from = aws_eks_node_group.app
  to   = module.eks.aws_eks_node_group.app
}

moved {
  from = aws_eks_addon.cni
  to   = module.eks.aws_eks_addon.cni
}

moved {
  from = aws_eks_addon.after_nodes
  to   = module.eks.aws_eks_addon.after_nodes
}

moved {
  from = data.tls_certificate.oidc
  to   = module.eks.data.tls_certificate.oidc
}

moved {
  from = aws_iam_openid_connect_provider.cluster
  to   = module.eks.aws_iam_openid_connect_provider.cluster
}

moved {
  from = aws_iam_role.controller
  to   = module.eks.aws_iam_role.controller
}

moved {
  from = aws_iam_policy.lbc
  to   = module.eks.aws_iam_policy.lbc
}

moved {
  from = aws_iam_role_policy_attachment.lbc
  to   = module.eks.aws_iam_role_policy_attachment.lbc
}

moved {
  from = aws_autoscaling_group_tag.discovery
  to   = module.eks.aws_autoscaling_group_tag.discovery
}

moved {
  from = aws_iam_role_policy.ca
  to   = module.eks.aws_iam_role_policy.ca
}
