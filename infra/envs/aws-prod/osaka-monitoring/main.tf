# Keep Osaka separate from the Azure DR reservation (10.30.0.0/24).
resource "aws_vpc" "osaka" {
  cidr_block = "10.40.0.0/16"

  tags = {
    Name = "osaka-observe"
  }
}

resource "aws_subnet" "osaka" {
  vpc_id                  = aws_vpc.osaka.id
  cidr_block              = "10.40.0.0/27"
  map_public_ip_on_launch = true

  tags = {
    Name = "osaka-observe"
  }
}
