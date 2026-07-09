##############################################################
# Data Sources
# Retrieve existing AWS resources from the Lab environment
##############################################################

# Get the existing Lab VPC
data "aws_vpc" "lab_vpc" {

  filter {
    name   = "tag:Name"
    values = ["Lab VPC"]
  }

}

# Get the existing EFS Client Security Group
data "aws_security_group" "efs_client_sg" {

  filter {
    name   = "group-name"
    values = ["EFSClient"]
  }

  vpc_id = data.aws_vpc.lab_vpc.id

}

# Get all subnets inside the Lab VPC
data "aws_subnets" "lab_subnets" {

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.lab_vpc.id]
  }

}

##############################################################
# Security Group
# Allows NFS traffic from EC2 instances to the EFS file system
##############################################################

resource "aws_security_group" "efs_mount_target_sg" {

  name        = "Terraform-EFS-MountTarget-SG"
  description = "Allow NFS traffic from EFS client instances"
  vpc_id      = data.aws_vpc.lab_vpc.id

  ingress {

    description = "NFS"

    from_port = 2049
    to_port   = 2049

    protocol = "tcp"

    security_groups = [
      data.aws_security_group.efs_client_sg.id
    ]

  }

  egress {

    description = "Allow all outbound traffic"

    from_port = 0
    to_port   = 0

    protocol = "-1"

    cidr_blocks = [
      "0.0.0.0/0"
    ]

  }

  tags = {

    Name        = "Terraform-EFS-MountTarget-SG"
    Project     = "Terraform AWS EFS Lab"
    Environment = "Lab"

  }

}##############################################################
# Amazon Elastic File System (EFS)
##############################################################

resource "aws_efs_file_system" "efs_storage" {

  creation_token = "terraform-efs-storage"

  encrypted = true

  performance_mode = "generalPurpose"

  throughput_mode = "bursting"

  tags = {

    Name = "Terraform-EFS-Storage"

    Project = "Terraform AWS EFS Lab"

    Environment = "Lab"

    ManagedBy = "Terraform"

  }

}