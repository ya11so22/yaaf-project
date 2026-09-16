output "vpc_id" {
  description = "ID of the created VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the created VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets, same order as var.availability_zones."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets, same order as var.availability_zones."
  value       = aws_subnet.private[*].id
}

output "availability_zones" {
  description = "Availability zones subnets were created in."
  value       = var.availability_zones
}

output "nat_gateway_ids" {
  description = "IDs of the NAT gateway(s)."
  value       = aws_nat_gateway.this[*].id
}
