# spk-2.1/modules/foundation/vpc/outputs.tf
# VPC module outputs

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway"
  value       = aws_nat_gateway.main.id
}

output "nat_gateway_eip" {
  description = "Elastic IP of the NAT Gateway"
  value       = aws_eip.nat.public_ip
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "public_subnet_cidr" {
  description = "CIDR block of the public subnet"
  value       = aws_subnet.public.cidr_block
}

output "private_external_subnet_ids" {
  description = "IDs of the private external subnets"
  value       = [aws_subnet.private_external_a.id, aws_subnet.private_external_b.id]
}

output "private_internal_subnet_ids" {
  description = "IDs of the private internal subnets"
  value       = [aws_subnet.private_internal_a.id, aws_subnet.private_internal_b.id]
}

output "all_private_subnet_ids" {
  description = "IDs of all private subnets"
  value = [
    aws_subnet.private_external_a.id,
    aws_subnet.private_external_b.id,
    aws_subnet.private_internal_a.id,
    aws_subnet.private_internal_b.id
  ]
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "ID of the private route table"
  value       = aws_route_table.private.id
}

output "availability_zones" {
  description = "Availability zones used by the VPC"
  value       = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1]]
}