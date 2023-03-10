terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Terraform   = true
      Environment = var.environment
      Name        = "${var.project_name}-${var.environment}-aws"
    }
  }
}

#####
#####

# To launch Amazon EC2 instances that are compatible with CodeDeploy, you must create an additional IAM role, an instance profile. 
# This role gives CodeDeploy permission to access the Amazon S3 buckets or GitHub repositories where your applications are stored.

data "aws_iam_policy_document" "assume_role_ec2" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "assume_role_code_deploy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }
  }
}

## EC2 
# data "aws_ami" "ami" {
#   most_recent = true

#   filter {
#     name   = "name"
#     values = ["amzn2-ami-hvm-*-x86_64-ebs"]
#   }

#   owners = ["amazon"]
# }

data "aws_ami" "ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.*-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

data "template_file" "userData" {
  template = file("${path.module}/userdata.tpl")
  vars = {
    code_deploy_bucket_name   = var.code_deploy_bucket_name
    code_deploy_region        = var.code_deploy_region
    public_key                = var.public_key
    code_deploy_agent_version = var.code_deploy_agent_version
  }
}

#####
#####

## Key Pair - needed in order to access the EC2 instance
resource "aws_key_pair" "deployer" {
  key_name   = join("_", [var.environment, "webserver_key"])
  public_key = var.public_key
}

# variable "ec2_key" {
#   type        = string
#   default     = "ec2-key"
#   description = "Key-pair generated by Terraform"
# }

# resource "tls_private_key" "test_key" {
#   algorithm = "RSA"
#   rsa_bits  = 4096
# }

# resource "aws_key_pair" "deployer" {
#   key_name   = var.ec2_key
#   public_key = tls_private_key.test_key.public_key_openssh

#   # Generate "ec2-key.pem" in current directory
#   provisioner "local-exec" {
#     command = <<-EOT
#       echo '${tls_private_key.dev_key.private_key_pem}' > ./'${var.ec2_key}'.pem
#       chmod 400 ./'${var.ec2_key}'.pem
#     EOT
#   }
# }

## Instance Role - In order for code deploy agent to access the S3 bucket
resource "aws_iam_role" "instance_role" {
  name               = "EC2_Role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_ec2.json
}

## Code deploy role - used to give AWS access to deploy to the EC2 instance
resource "aws_iam_role" "code_deploy_role" {
  name               = "CodeDeploy_Role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_code_deploy.json
}

resource "aws_iam_instance_profile" "webserver_profile" {
  name = "webserver_profile"
  role = aws_iam_role.instance_role.name
}

# VPC
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.project_name}-${var.environment}-vpc"
  cidr = var.vpc_cidr

  azs            = ["${var.region}a", "${var.region}c"]
  public_subnets = var.vpc_public_subnet_cidrs

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Default security group - ingress/egress rules cleared to deny all
  manage_default_security_group  = true
  default_security_group_ingress = [{}]
  default_security_group_egress  = [{}]

  public_subnet_tags = {
    Name = "public-subnet"
  }
}

### Security Groups
module "security_groups" {
  source = "terraform-aws-modules/security-group/aws"

  name   = "${var.project_name}-security-group"
  vpc_id = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["https-443-tcp", "http-80-tcp", "ssh-tcp"]
  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = -1
      description = "Allow all Outgoing"
      cidr_blocks = "0.0.0.0/0"
    },
  ]
}

# resource "aws_instance" "web" {
resource "aws_spot_instance_request" "web" {
  ami                         = data.aws_ami.ami.id
  instance_type               = "t3.nano"
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.webserver_profile.name
  key_name                    = aws_key_pair.deployer.id
  # security_groups             = [module.security_groups.security_group_id]
  vpc_security_group_ids = [module.security_groups.security_group_id]
  user_data              = data.template_file.userData.rendered
  subnet_id              = element(module.vpc.public_subnets, 0)

  wait_for_fulfillment = true
  spot_type            = "one-time"
}

resource "aws_eip" "ip" {
  instance = aws_spot_instance_request.web.spot_instance_id
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_spot_instance_request.web.spot_instance_id
  allocation_id = aws_eip.ip.id
}
