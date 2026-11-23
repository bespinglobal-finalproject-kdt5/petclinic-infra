mock_provider "aws" {
  source = "./tests/mocks"
}

run "private_postgres_from_eks" {
  command = plan
  module { source = "./database" }
  variables {
    vpc_id                    = "vpc-00000000000000001"
    db_subnet_ids             = ["subnet-00000000000000003", "subnet-00000000000000004"]
    cluster_security_group_id = "sg-00000000000000001"
  }
  assert {
    condition = (
      aws_db_instance.petclinic.multi_az && !aws_db_instance.petclinic.publicly_accessible &&
      aws_db_instance.petclinic.storage_encrypted && aws_db_instance.petclinic.manage_master_user_password &&
      aws_db_instance.petclinic.deletion_protection && aws_db_instance.petclinic.backup_retention_period >= 7 &&
      aws_db_subnet_group.petclinic.subnet_ids == toset(var.db_subnet_ids) &&
      aws_security_group.postgres.vpc_id == var.vpc_id &&
      aws_vpc_security_group_ingress_rule.eks_postgres.referenced_security_group_id == var.cluster_security_group_id &&
      aws_vpc_security_group_ingress_rule.eks_postgres.from_port == 5432 && aws_vpc_security_group_ingress_rule.eks_postgres.to_port == 5432
    )
    error_message = "PostgreSQL must use the DB subnets and permit EKS access on 5432 with backup and deletion protection."
  }
}
