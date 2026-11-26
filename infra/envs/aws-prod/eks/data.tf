data "aws_vpc" "service" {
  id = var.service_vpc_id
}

data "aws_subnet" "private" {
  for_each = {
    app_1 = var.app_subnet_ids[0]
    app_2 = var.app_subnet_ids[1]
  }
  id = each.value
}

data "tls_certificate" "oidc" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}
