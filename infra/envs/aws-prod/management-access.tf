locals {
  # The role name is set by the module and is known before AWS creates the role.
  management_role_key = "arn:aws:iam::${var.aws_account_id}:role/${module.seoul_vpc2.management_role_name}"
  cluster_admins = merge(
    { for arn in var.admin_principal_arns : arn => arn },
    { (local.management_role_key) = module.seoul_vpc2.management_role_arn },
  )
}

resource "aws_iam_role_policy" "management_eks" {
  name = "petclinic-prod-eks-describe"
  role = module.seoul_vpc2.management_role_name
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = ["eks:DescribeCluster"], Resource = "arn:aws:eks:${var.aws_region}:${var.aws_account_id}:cluster/${var.cluster_name}" }]
  })
}
