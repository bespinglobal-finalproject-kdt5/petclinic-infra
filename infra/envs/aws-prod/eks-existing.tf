locals {
  private_subnet_ids = toset(module.seoul_vpc1.app_subnet_ids)
  cluster_admins     = setunion(var.admin_principal_arns, toset([module.seoul_vpc2.management_role_arn]))
  lbc_version        = "3.6.3"
}
data "aws_vpc" "service" {
  id = module.seoul_vpc1.service_vpc_id
}
data "aws_subnet" "private" {
  for_each = local.private_subnet_ids
  id       = each.value
}
resource "aws_iam_role_policy" "management_eks" {
  name = "petclinic-prod-eks-describe"
  role = module.seoul_vpc2.management_role_name
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = ["eks:DescribeCluster"], Resource = "arn:aws:eks:${var.aws_region}:${var.aws_account_id}:cluster/${var.cluster_name}" }]
  })
}