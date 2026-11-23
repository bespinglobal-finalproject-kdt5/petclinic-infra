# EKS resources previously declared directly in aws-prod.
moved {
  from = aws_iam_role.eks_control_plane
  to   = module.eks.aws_iam_role.eks_control_plane
}

moved {
  from = aws_iam_role_policy_attachment.eks_control_plane
  to   = module.eks.aws_iam_role_policy_attachment.eks_control_plane
}

moved {
  from = aws_eks_cluster.petclinic
  to   = module.eks.aws_eks_cluster.petclinic
}

moved {
  from = aws_iam_role.eks_node
  to   = module.eks.aws_iam_role.eks_node
}

moved {
  from = aws_iam_role_policy_attachment.eks_node
  to   = module.eks.aws_iam_role_policy_attachment.eks_node
}

moved {
  from = aws_iam_openid_connect_provider.eks
  to   = module.eks.aws_iam_openid_connect_provider.eks
}

moved {
  from = aws_iam_role.eks_cni
  to   = module.eks.aws_iam_role.eks_cni
}

moved {
  from = aws_iam_role_policy_attachment.eks_cni
  to   = module.eks.aws_iam_role_policy_attachment.eks_cni
}

moved {
  from = aws_eks_addon.vpc_cni
  to   = module.eks.aws_eks_addon.vpc_cni
}

moved {
  from = aws_launch_template.app_nodes
  to   = module.eks.aws_launch_template.app_nodes
}

moved {
  from = aws_eks_node_group.app
  to   = module.eks.aws_eks_node_group.app
}

# Move the former root edge resources into their environment module.
moved {
  from = data.aws_ec2_managed_prefix_list.cloudfront
  to   = module.edge.data.aws_ec2_managed_prefix_list.cloudfront
}

moved {
  from = aws_security_group.origin
  to   = module.edge.aws_security_group.origin
}

moved {
  from = aws_vpc_security_group_ingress_rule.cloudfront_http
  to   = module.edge.aws_vpc_security_group_ingress_rule.cloudfront_http
}

moved {
  from = aws_lb.origin
  to   = module.edge.aws_lb.origin
}

moved {
  from = aws_lb_listener.http
  to   = module.edge.aws_lb_listener.http
}

moved {
  from = aws_lb_listener_rule.health
  to   = module.edge.aws_lb_listener_rule.health
}

moved {
  from = aws_lb_target_group.app
  to   = module.edge.aws_lb_target_group.app
}

moved {
  from = aws_autoscaling_attachment.app
  to   = module.edge.aws_autoscaling_attachment.app
}

moved {
  from = aws_vpc_security_group_egress_rule.alb_to_node
  to   = module.edge.aws_vpc_security_group_egress_rule.alb_to_node
}

moved {
  from = aws_vpc_security_group_ingress_rule.node_from_alb
  to   = module.edge.aws_vpc_security_group_ingress_rule.node_from_alb
}

moved {
  from = aws_lb_listener_rule.app
  to   = module.edge.aws_lb_listener_rule.app
}

moved {
  from = data.aws_cloudfront_origin_request_policy.api
  to   = module.edge.data.aws_cloudfront_origin_request_policy.api
}

moved {
  from = data.aws_cloudfront_cache_policy.disabled
  to   = module.edge.data.aws_cloudfront_cache_policy.disabled
}

moved {
  from = aws_cloudfront_vpc_origin.alb
  to   = module.edge.aws_cloudfront_vpc_origin.alb
}

moved {
  from = aws_cloudfront_distribution.edge
  to   = module.edge.aws_cloudfront_distribution.edge
}

moved {
  from = aws_route53_zone.delegated
  to   = module.edge.aws_route53_zone.delegated
}

moved {
  from = aws_acm_certificate.viewer
  to   = module.edge.aws_acm_certificate.viewer
}

moved {
  from = aws_route53_record.validation
  to   = module.edge.aws_route53_record.validation
}

moved {
  from = aws_acm_certificate_validation.viewer
  to   = module.edge.aws_acm_certificate_validation.viewer
}

moved {
  from = aws_route53_record.viewer
  to   = module.edge.aws_route53_record.viewer
}

# Move the former root database resources into their environment module.
moved {
  from = aws_db_subnet_group.petclinic
  to   = module.database.aws_db_subnet_group.petclinic
}

moved {
  from = aws_security_group.postgres
  to   = module.database.aws_security_group.postgres
}

moved {
  from = aws_vpc_security_group_ingress_rule.eks_postgres
  to   = module.database.aws_vpc_security_group_ingress_rule.eks_postgres
}

moved {
  from = aws_db_instance.petclinic
  to   = module.database.aws_db_instance.petclinic
}

moved {
  from = aws_vpc_peering_connection.seoul_osaka
  to   = module.osaka_observe.aws_vpc_peering_connection.seoul_osaka
}

moved {
  from = aws_vpc_peering_connection_accepter.osaka
  to   = module.osaka_observe.aws_vpc_peering_connection_accepter.osaka
}
