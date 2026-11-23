resource "aws_iam_role" "eks_node" {
  name = "${var.name}-eks-node"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = merge(var.tags, { Name = "${var.name}-eks-node" })
}

resource "aws_iam_role_policy_attachment" "eks_node" {
  for_each   = toset(["AmazonEKSWorkerNodePolicy", "AmazonEC2ContainerRegistryPullOnly"])
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/${each.key}"
}

# No custom SG: EKS attaches its cluster SG to every managed node. The default
# VPC CNI uses node ENI SGs for pod traffic (including pod -> RDS).
resource "aws_launch_template" "app_nodes" {
  name_prefix = "${var.name}-app-"
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      encrypted             = true
      volume_size           = 20
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }
  dynamic "tag_specifications" {
    for_each = toset(["instance", "volume"])
    content {
      resource_type = tag_specifications.value
      tags          = merge(var.tags, { Name = "${var.name}-app-node" })
    }
  }
  tags = merge(var.tags, { Name = "${var.name}-app-template" })
}

resource "aws_eks_node_group" "app" {
  cluster_name    = aws_eks_cluster.petclinic.name
  node_group_name = "${var.name}-app"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = var.subnet_ids
  version         = aws_eks_cluster.petclinic.version
  ami_type        = var.ami_type
  release_version = var.node_ami_release
  instance_types  = ["t3.medium"]
  capacity_type   = "ON_DEMAND"
  scaling_config {
    min_size     = 2
    desired_size = 2
    max_size     = 2
  }
  launch_template {
    id      = aws_launch_template.app_nodes.id
    version = aws_launch_template.app_nodes.latest_version
  }
  update_config { max_unavailable = 1 }
  tags       = merge(var.tags, { Name = "${var.name}-app-nodes" })
  depends_on = [aws_iam_role_policy_attachment.eks_node, aws_eks_addon.vpc_cni]
}
