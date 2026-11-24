resource "aws_launch_template" "node" {
  name_prefix = "${var.cluster_name}-node-"

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }
}

resource "aws_eks_node_group" "app" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "app"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = module.seoul_vpc1.app_subnet_ids
  version         = var.kubernetes_version
  ami_type        = "AL2023_x86_64_STANDARD"
  release_version = var.node_release_version
  instance_types  = [var.node_instance_type]
  capacity_type   = "ON_DEMAND"
  labels          = { workload = "petclinic" }

  launch_template {
    id      = aws_launch_template.node.id
    version = aws_launch_template.node.latest_version
  }
  scaling_config {
    min_size     = var.node_scaling.min
    desired_size = var.node_scaling.desired
    max_size     = var.node_scaling.max
  }
  update_config {
    max_unavailable = 1
  }
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
  depends_on = [aws_iam_role_policy_attachment.node, aws_eks_addon.cni]
}
