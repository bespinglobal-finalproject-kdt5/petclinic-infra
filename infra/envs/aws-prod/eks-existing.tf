locals {
  private_subnet_ids = toset(module.seoul_vpc1.app_subnet_ids)

  # The role name is set by the module and is known before AWS creates the role.
  management_role_key = "arn:aws:iam::${var.aws_account_id}:role/${module.seoul_vpc2.management_role_name}"
  cluster_admins = merge(
    { for arn in var.admin_principal_arns : arn => arn },
    { (local.management_role_key) = module.seoul_vpc2.management_role_arn },
  )
  lbc_version = "3.6.3"
}
data "aws_vpc" "service" {
  id = module.seoul_vpc1.service_vpc_id
}
data "aws_subnet" "private" {
  for_each = {
    app_1 = module.seoul_vpc1.app_subnet_ids[0]
    app_2 = module.seoul_vpc1.app_subnet_ids[1]
  }
  id = each.value
}
resource "aws_iam_role_policy" "management_eks" {
  name = "petclinic-prod-eks-describe"
  role = module.seoul_vpc2.management_role_name
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = ["eks:DescribeCluster"], Resource = "arn:aws:eks:${var.aws_region}:${var.aws_account_id}:cluster/${var.cluster_name}" }]
  })
}
