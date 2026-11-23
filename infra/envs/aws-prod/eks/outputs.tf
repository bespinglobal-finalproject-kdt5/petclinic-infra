output "cluster_security_group_id" {
  description = "EKS security group shared by the cluster and managed nodes."
  value       = aws_eks_cluster.petclinic.vpc_config[0].cluster_security_group_id
}

output "node_autoscaling_group_name" {
  description = "Managed node Auto Scaling group attached to the application's ALB target groups."
  value       = aws_eks_node_group.app.resources[0].autoscaling_groups[0].name
}
