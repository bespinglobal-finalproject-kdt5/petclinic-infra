mock_provider "aws" {
  source = "./tests/mocks"
}

run "private_cluster_and_managed_nodes" {
  command = plan
  module { source = "./eks" }
  variables {
    name               = "petclinic-test"
    tags               = { project = "petclinic", component = "app" }
    subnet_ids         = ["subnet-00000000000000001", "subnet-00000000000000002"]
    kubernetes_version = "1.36"
    ami_type           = "AL2023_x86_64_STANDARD"
    # Synthetic builds exercise the inputs without selecting production releases.
    node_ami_release = "1.36.0-20000101"
    vpc_cni_version  = "v1.0.0-eksbuild.1"
  }

  assert {
    condition = (
      aws_eks_cluster.petclinic.vpc_config[0].endpoint_private_access &&
      !aws_eks_cluster.petclinic.vpc_config[0].endpoint_public_access &&
      aws_eks_cluster.petclinic.vpc_config[0].subnet_ids == toset(var.subnet_ids) &&
      aws_eks_node_group.app.subnet_ids == toset(var.subnet_ids)
    )
    error_message = "The cluster needs a private-only endpoint and both resources must use the application subnets."
  }

  assert {
    condition = (
      aws_eks_cluster.petclinic.version == var.kubernetes_version &&
      aws_eks_node_group.app.version == aws_eks_cluster.petclinic.version &&
      aws_eks_node_group.app.ami_type == var.ami_type &&
      aws_eks_node_group.app.release_version == var.node_ami_release &&
      aws_eks_addon.vpc_cni.addon_version == var.vpc_cni_version
    )
    error_message = "Use the requested Kubernetes minor, node image and VPC CNI build."
  }
}
