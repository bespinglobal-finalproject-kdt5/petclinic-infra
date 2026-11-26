# Pin the Ubuntu release used by both hosts.
data "aws_ami" "ubuntu" {
  owners = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-20261120"]
  }
}
