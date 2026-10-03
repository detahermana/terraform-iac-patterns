output "vpc_id" {
  description = "ID of the VPC, whether created by this call or supplied via var.vpc_id."
  value       = local.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC. Reflects the created VPC when one was made, otherwise the value passed in."
  value       = var.vpc_id == null ? aws_vpc.this[0].cidr_block : var.vpc_cidr
}

output "public_subnet_ids" {
  description = "IDs of the public subnets, in the order their CIDRs were supplied."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets, in the order their CIDRs were supplied."
  value       = aws_subnet.private[*].id
}

output "internet_gateway_id" {
  description = "ID of the internet gateway, or null when none was created."
  value       = var.create_internet_gateway && var.vpc_id == null ? aws_internet_gateway.this[0].id : null
}

output "security_group_ids" {
  description = "Map of security group name -> ID. Consumers attach these to instances and load balancers."
  value       = { for k, sg in aws_security_group.this : k => sg.id }
}
