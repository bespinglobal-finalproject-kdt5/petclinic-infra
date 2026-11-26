output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_security_group_id" {
  value = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "lbc_role_arn" {
  value = aws_iam_role.controller["lbc"].arn
}

output "ca_role_arn" {
  value = aws_iam_role.controller["ca"].arn
}
