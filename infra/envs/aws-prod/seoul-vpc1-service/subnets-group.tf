resource "aws_db_subnet_group" "petclinic" {
  name        = "db-subnet-group"
  description = "db-subnet-group"

  subnet_ids = [
    aws_subnet.service["db_1"].id,
    aws_subnet.service["db_2"].id,
  ]
}
