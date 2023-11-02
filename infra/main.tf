module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  # Details
  name            = "${var.name}-${local.name}"
  cidr            = var.cidr
  azs             = var.azs
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  database_subnets                   = var.database_subnets
  create_database_subnet_group       = var.create_database_subnet_group
  create_database_subnet_route_table = var.create_database_subnet_route_table

  # NAT Gateways - Outbound Communication
  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway

  # DNS Parameters in VPC
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Additional tags for the VPC
  tags     = local.tags
  vpc_tags = local.tags

  # Additional tags
  # Additional tags for the public subnets
  public_subnet_tags = {
    Name = "VPC Public Subnets"
  }
  # Additional tags for the private subnets
  private_subnet_tags = {
    Name = "VPC Private Subnets"
  }
  # Additional tags for the database subnets
  database_subnet_tags = {
    Name = "VPC Private Database Subnets"
  }
  # Instances launched into the Public subnet should be assigned a public IP address. Specify true to indicate that instances launched into the subnet should be assigned a public IP address
  map_public_ip_on_launch = true
}


data "aws_ami" "amazon_linux_ami" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-*-gp2"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


# Security Group for Public Bastion Host
# https://registry.terraform.io/modules/terraform-aws-modules/security-group/aws/latest
module "bastion_instance_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.1.0"

  name        = "bastion-instance-sg-${local.name}"
  description = "SSH port open, egress ports are all world open"
  vpc_id      = module.vpc.vpc_id

  # List of ingress rules and CIDR Block
  ingress_rules       = ["ssh-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]

  # List of egress rules to create by name open to all-all
  egress_rules = ["all-all"]
  tags         = local.tags
}


data "aws_key_pair" "example" {
  key_name = "seba-mac"
}

# Terraform Module for Bastion instance - bastion Instance that will be created in VPC Public Subnet
# https://registry.terraform.io/modules/terraform-aws-modules/ec2-instance/aws/latest
module "ec2_bastion_instance" {
  source                 = "terraform-aws-modules/ec2-instance/aws"
  version                = "5.2.0"
  name                   = "Bastion-Instance-${local.name}"
  ami                    = data.aws_ami.amazon_linux_ami.id
  instance_type          = var.instance_type
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [module.bastion_instance_sg.security_group_id]
  key_name               = data.aws_key_pair.example.key_name
  tags                   = local.tags
  depends_on = [
    module.vpc
  ]
}


# Elastic IP for Bastion Instance
# https://registry.terraform.io/providers/hashicorp/aws/2.42.0/docs/resources/eip
resource "aws_eip" "bastion_instance_eip" {
  #   vpc      = true
  domain   = "vpc"      # vpc argument to the aws_eip resource is deprecated
  instance = module.ec2_bastion_instance.id
  tags     = local.tags
  depends_on = [
    module.ec2_bastion_instance,
    module.vpc
  ]
}

resource "aws_security_group" "rds_sg" {
  name = "rds_sg"
  vpc_id      = module.vpc.vpc_id 
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "default" {
  name       = "main"
  subnet_ids = [module.vpc.public_subnets[0],module.vpc.public_subnets[1],module.vpc.public_subnets[2]]
}

resource "aws_db_parameter_group" "example" {
  name   = "my-pg"
  family = "postgres15"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_instance" "myinstance" {
  engine               = "postgres"
  identifier           = "myrdsinstance"
  allocated_storage    =  20
  engine_version       = "15.3"
  instance_class       = "db.t3.micro"
  db_name              = "store"
  db_subnet_group_name = aws_db_subnet_group.default.name
  username             = "postgres"
  password             = "myrdspassword"
  parameter_group_name = aws_db_parameter_group.example.name
  vpc_security_group_ids = ["${aws_security_group.rds_sg.id}"]
  skip_final_snapshot  = true
  publicly_accessible =  false
}

resource "aws_ecr_repository" "my_ecr" {
  name = "my-birthday-app-dev"  
}

module "eks" {
  source      = "terraform-aws-modules/eks/aws"
  cluster_name = var.cluster_name
  cluster_version = "1.28"

  subnet_ids = module.vpc.private_subnets
  vpc_id =  module.vpc.vpc_id
  cluster_endpoint_public_access = true
}

module "eks_managed_node_group" {
  source = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"

  name            = "separate-eks-mng"
  cluster_name    = module.eks.cluster_name
  cluster_version = "1.28"

  subnet_ids = module.vpc.private_subnets

  cluster_primary_security_group_id = module.eks.cluster_primary_security_group_id
  vpc_security_group_ids            = [module.eks.node_security_group_id]

  min_size     = 1
  max_size     = 10
  desired_size = 1

  instance_types = ["t3.micro"]
  capacity_type  = "SPOT"

  labels = {
    Environment = "test"
    GithubRepo  = "terraform-aws-eks"
    GithubOrg   = "terraform-aws-modules"
  }

  taints = {
    dedicated = {
      key    = "dedicated"
      value  = "gpuGroup"
      effect = "NO_SCHEDULE"
    }
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}