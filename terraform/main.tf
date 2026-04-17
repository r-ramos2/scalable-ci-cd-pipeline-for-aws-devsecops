locals {
  project_name = "aws-devsecops-homelab"
  common_tags = {
    Project     = local.project_name
    ManagedBy   = "Terraform"
    Environment = "Development"
  }
}

# ============================================
# 1. SSH Keypair Generation
# ============================================
resource "tls_private_key" "deployer" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_key_pair" "deployer" {
  key_name   = "${var.key_name_prefix}-${random_id.suffix.hex}"
  public_key = tls_private_key.deployer.public_key_openssh

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-keypair"
  })
}

resource "local_file" "private_key_pem" {
  content         = tls_private_key.deployer.private_key_pem
  filename        = "${path.module}/deployer_key.pem"
  file_permission = "0400"
}

# ============================================
# 2. AMI Data Source (Amazon Linux 2)
# ============================================
data "aws_ami" "linux2" {
  most_recent = true
  owners      = [var.linux2_ami_owner]

  filter {
    name   = "name"
    values = [var.linux2_ami_name_filter]
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

# ============================================
# 3. Networking: VPC, Subnet, IGW, Routing
# ============================================
resource "aws_vpc" "lab" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-vpc"
  })
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-public-subnet"
  })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.lab.id

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-igw"
  })
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.lab.id

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-rt"
  })
}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.rt.id
}

# ============================================
# 4. Security Group
# ============================================
resource "aws_security_group" "jenkins_sg" {
  name        = "${local.project_name}-sg"
  description = "Security group for DevSecOps Jenkins instance"
  vpc_id      = aws_vpc.lab.id

  # SSH access
  ingress {
    description = "SSH from allowed CIDR"
    from_port   = var.ssh_port
    to_port     = var.ssh_port
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # HTTP access
  ingress {
    description = "HTTP from allowed CIDR"
    from_port   = var.http_port
    to_port     = var.http_port
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # HTTPS access
  ingress {
    description = "HTTPS from allowed CIDR"
    from_port   = var.https_port
    to_port     = var.https_port
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # Jenkins Web UI
  ingress {
    description = "Jenkins UI from allowed CIDR"
    from_port   = var.jenkins_port
    to_port     = var.jenkins_port
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # SonarQube UI
  ingress {
    description = "SonarQube UI from allowed CIDR"
    from_port   = var.sonarqube_port
    to_port     = var.sonarqube_port
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # React App
  ingress {
    description = "React App from allowed CIDR"
    from_port   = var.react_port
    to_port     = var.react_port
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # Outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-sg"
  })
}

# ============================================
# 5. EC2 Instance (Jenkins Server)
# ============================================
resource "aws_instance" "jenkins" {
  ami                         = data.aws_ami.linux2.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.jenkins_sg.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.deployer.key_name
  user_data                   = file("${path.module}/../scripts/install_jenkins.sh")

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true

    tags = merge(local.common_tags, {
      Name = "${local.project_name}-jenkins-root-volume"
    })
  }

  # Use on-demand instances for reliability
  # Note: Spot instances can be terminated with 2-minute notice
  # Uncomment the block below to use Spot instances (cost savings)
  # instance_market_options {
  #   market_type = "spot"
  #   spot_options {
  #     allocation_strategy            = "capacity-optimized"
  #     instance_interruption_behavior = "terminate"
  #     spot_instance_type             = "one-time"
  #   }
  # }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-jenkins-server"
  })
}
