

data "aws_vpc" "lab_vpc" {
  # Option 1: Fetch by name tag (recommended)
  filter {
    name   = "tag:Name"
    values = ["Lab VPC"]  
  }

}

data "aws_subnets" "lab_vpc_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.lab_vpc.id]
  }
}

data "aws_security_group" "efs_client_security_group" {
  # Option 1: Fetch by name tag
  filter {
    name   = "group-name"
    values = ["EFSClient"]  # ← UPDATE: Change to match your EFSClient SG name
  }

  # Option 2: Fetch by Security Group ID (if you know it)
  # id = "sg-03727965651b6659b"

  # Ensure we fetch from the correct VPC
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.lab_vpc.id]
  }
}


# ============================================
# RESOURCES - Security Group for EFS Mount Targets
# ============================================

# ----------------------------------------------------------------------
# RESOURCE: Security Group for EFS Mount Targets
# This allows NFS traffic (port 2049) from the EFSClient SG
# ----------------------------------------------------------------------
resource "aws_security_group" "efs_mount_target_security_group" {
  name        = "EFS Mount Target"
  description = "Inbound NFS access from EFS clients"
  vpc_id      = data.aws_vpc.lab_vpc.id

  # Inbound Rule: Allow NFS (port 2049) from EFSClient security group
  ingress {
    description     = "Allow NFS from EFS client instances"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [data.aws_security_group.efs_client_security_group.id]
  }

  # Outbound Rule: Allow all outbound traffic (default for security groups)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "EFS Mount Target"
    Environment = "Lab"
    Project     = "EFS-Demo"
  }
}


# ============================================
# RESOURCES - EFS File System
# ============================================

# ----------------------------------------------------------------------
# RESOURCE: EFS File System
# This creates the actual EFS filesystem with specific configurations
# ----------------------------------------------------------------------
resource "aws_efs_file_system" "my_first_efs_filesystem" {
  creation_token = "my-first-efs-filesystem-token"

  # Performance Configuration
  performance_mode = "generalPurpose"  # Options: generalPurpose | maxIO
  throughput_mode  = "bursting"        # Options: bursting | provisioned

  # Lifecycle Management - No IA Transition as per lab
  lifecycle_policy {
    transition_to_ia = "DISABLED"  # Options: AFTER_30_DAYS | AFTER_60_DAYS | etc.
  }

  # Backup Configuration - Disabled as per lab
  enable_backup = false

  # Tags for identification
  tags = {
    Name        = "My First EFS File System"
    Environment = "Lab"
    Project     = "EFS-Demo"
  }
}

# ----------------------------------------------------------------------
# RESOURCE: EFS Mount Targets (One per subnet/Availability Zone)
# These allow EC2 instances in different AZs to mount the EFS
# ----------------------------------------------------------------------
resource "aws_efs_mount_target" "efs_mount_target_per_subnet" {
  count = length(data.aws_subnets.lab_vpc_subnets.ids)

  file_system_id  = aws_efs_file_system.my_first_efs_filesystem.id
  subnet_id       = data.aws_subnets.lab_vpc_subnets.ids[count.index]
  security_groups = [aws_security_group.efs_mount_target_security_group.id]

  # Ensure the file system is available before creating mount targets
  depends_on = [
    aws_efs_file_system.my_first_efs_filesystem,
    aws_security_group.efs_mount_target_security_group
  ]

  tags = {
    Name          = "efs-mount-target-${count.index + 1}"
    Subnet        = data.aws_subnets.lab_vpc_subnets.ids[count.index]
    Environment   = "Lab"
    Project       = "EFS-Demo"
  }
}


# ============================================
# OUTPUTS - Useful Information for Next Steps
# ============================================

# ----------------------------------------------------------------------
# OUTPUT: EFS File System ID
# Useful for referencing this EFS in other Terraform configurations
# ----------------------------------------------------------------------
output "efs_filesystem_id" {
  description = "The unique ID of the EFS file system"
  value       = aws_efs_file_system.my_first_efs_filesystem.id
}

# ----------------------------------------------------------------------
# OUTPUT: EFS DNS Name
# This is the hostname used to mount the EFS from EC2 instances
# ----------------------------------------------------------------------
output "efs_dns_name" {
  description = "The DNS name of the EFS file system (use this to mount)"
  value       = aws_efs_file_system.my_first_efs_filesystem.dns_name
}

# ----------------------------------------------------------------------
# OUTPUT: EFS ARN
# Amazon Resource Name - useful for IAM policies
# ----------------------------------------------------------------------
output "efs_arn" {
  description = "The ARN of the EFS file system"
  value       = aws_efs_file_system.my_first_efs_filesystem.arn
}

# ----------------------------------------------------------------------
# OUTPUT: Mount Target IDs
# List of all mount target IDs created
# ----------------------------------------------------------------------
output "mount_target_ids" {
  description = "IDs of all mount targets created in each subnet"
  value       = aws_efs_mount_target.efs_mount_target_per_subnet[*].id
}

# ----------------------------------------------------------------------
# OUTPUT: Mount Target IP Addresses
# IP addresses assigned to each mount target
# ----------------------------------------------------------------------
output "mount_target_ip_addresses" {
  description = "IP addresses of all mount targets"
  value       = aws_efs_mount_target.efs_mount_target_per_subnet[*].ip_address
}

# ----------------------------------------------------------------------
# OUTPUT: Mount Command (Ready to Use)
# Pre-formatted command to mount the EFS on an EC2 instance
# ----------------------------------------------------------------------
output "efs_mount_command" {
  description = "Ready-to-use mount command for EC2 instances"
  value       = <<-EOT
    # Run these commands on your EC2 instance:
    sudo su -l ec2-user
    sudo yum install -y amazon-efs-utils
    sudo mkdir -p /home/ec2-user/efs
    sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${aws_efs_file_system.my_first_efs_filesystem.dns_name}:/ /home/ec2-user/efs
  EOT
}

# ----------------------------------------------------------------------
# OUTPUT: FSTAB Entry (For Persistent Mounts After Reboot)
# This can be added to /etc/fstab for automatic mounting on boot
# ----------------------------------------------------------------------
output "efs_fstab_entry" {
  description = "FSTAB entry for persistent mounting after instance reboot"
  value       = "${aws_efs_file_system.my_first_efs_filesystem.dns_name}:/ /home/ec2-user/efs nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev 0 0"
}

# ----------------------------------------------------------------------
# OUTPUT: Security Group Information
# Useful for attaching to other resources
# ----------------------------------------------------------------------
output "efs_mount_target_security_group_id" {
  description = "The ID of the EFS Mount Target security group"
  value       = aws_security_group.efs_mount_target_security_group.id
}

output "efs_client_security_group_id" {
  description = "The ID of the EFS Client security group (referenced from existing)"
  value       = data.aws_security_group.efs_client_security_group.id
}