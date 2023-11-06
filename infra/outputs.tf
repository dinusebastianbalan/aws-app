# VPC ID
output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

# VPC CIDR blocks
output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

# VPC Private Subnets
output "private_subnets" {
  description = "A list of private subnets inside the VPC"
  value       = module.vpc.private_subnets
}

# VPC Public Subnets
output "public_subnets" {
  description = "A list of public subnets inside the VPC"
  value       = module.vpc.public_subnets
}

# VPC NAT gateway Public IP
output "nat_public_ips" {
  description = "List of public Elastic IPs created for AWS NAT Gateway"
  value       = module.vpc.nat_public_ips
}

# VPC AZs
output "azs" {
  description = "A list of availability zones specified as argument to this module"
  value       = module.vpc.azs
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

#Bastion

## ec2_bastion_instance_ids
output "ec2_bastion_instance_ids" {
  description = "Bastion Instance ID"
  value       = module.ec2_bastion_instance.id
}

## ec2_bastion_public_ip
output "bastion_instance_eip" {
  description = "Elastic IP associated to the Bastion Host"
  value       = aws_eip.bastion_instance_eip.public_ip
}


output "kubeconfig" {
  value = abspath("${path.root}/${local_file.kubeconfig.filename}")
}