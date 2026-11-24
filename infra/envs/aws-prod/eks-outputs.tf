output "eks_manual_values" {
  value = {
    cluster_name             = aws_eks_cluster.this.name
    service_vpc              = module.seoul_vpc1.service_vpc_id
    app_subnets              = module.seoul_vpc1.app_subnet_ids
    public_subnets           = module.seoul_vpc1.public_subnet_ids
    management_nat_public_ip = module.seoul_vpc2.management_nat_public_ip
    management_instance      = module.seoul_vpc2.management_instance_id
    management_ip            = module.seoul_vpc2.management_private_ip
    management_role          = module.seoul_vpc2.management_role_arn
    lbc_role                 = aws_iam_role.controller["lbc"].arn
    ca_role                  = aws_iam_role.controller["ca"].arn
  }
}