provider "aws" {
  region = var.region
}

terraform {
  backend "s3" {
    bucket = "lago-terraform-state"
    key    = "prod/terraform.tfstate"
    region = "eu-north-1"
  }
}

variable "region" {
  type    = string
  default = "eu-north-1"
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "ami_id" {
  type    = string
  default = "ami-075449515af5df0d1"
}

variable "key_pair_name" {
  type    = string
  default = "etch@stakpak.dev"
}

variable "s3_bucket" {
  type = string
  default = "lago-storage-bucket"
}

variable "security_group_name" {
  type    = string
  default = "lago-security-group"
}

data "aws_vpc" "prod" {
  filter {
    name   = "tag:Name"
    values = ["prod"]
  }
}

data "aws_subnet" "prod_public" {
  filter {
    name   = "tag:Name"
    values = ["prod-public-eu-north-1a"]
  }
  vpc_id = data.aws_vpc.prod.id
}

data "aws_route53_zone" "stakpak_dev" {
  name         = "stakpak.dev."
  private_zone = false
  # provider = aws.virginia
}

resource "aws_security_group" "this" {
  name        = var.security_group_name
  description = "Allow inbound traffic on ports 22, 3000, and 80"
  vpc_id      = data.aws_vpc.prod.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_eip" "lago" {
  instance = aws_instance.lago.id
  domain   = "vpc"
}

resource "aws_instance" "lago" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.this.id]
  subnet_id              = data.aws_subnet.prod_public.id

  tags = {
    Name        = "lago"
    Description = "Billing Service"
  }

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }
}

resource "aws_route53_record" "billing" {
  zone_id = data.aws_route53_zone.stakpak_dev.zone_id
  name    = "billing.stakpak.dev"
  type    = "A"
  ttl     = 300
  records = [aws_eip.lago.public_ip]
}

resource "aws_route53_record" "billing_api" {
  zone_id = data.aws_route53_zone.stakpak_dev.zone_id
  name    = "billing-api.stakpak.dev"
  type    = "A"
  ttl     = 300
  records = [aws_eip.lago.public_ip]
}

resource "aws_s3_bucket" "lago_bucket" {
  bucket = var.s3_bucket
  
  tags = {
    Name        = "Lago storage bucket"
  }
}

resource "aws_iam_user" "lago_user" {
  name = "lago-s3-user"
}

resource "aws_iam_policy" "lago_s3_policy" {
  name        = "LagoS3AccessPolicy"
  description = "IAM policy to access the Lago S3 bucket"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "s3:*"
        Resource = "arn:aws:s3:::${var.s3_bucket}/*"
      },
      {
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = "arn:aws:s3:::${var.s3_bucket}"
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "lago_user_policy" {
  name       = "lago-s3-policy-attachment"
  users      = [aws_iam_user.lago_user.name]
  policy_arn = aws_iam_policy.lago_s3_policy.arn
}

resource "aws_iam_access_key" "lago_access_key" {
  user = aws_iam_user.lago_user.name
}


output "LAGO_AWS_S3_ACCESS_KEY_ID" {
  value = aws_iam_access_key.lago_access_key.id
  sensitive = true
}

output "LAGO_AWS_S3_SECRET_ACCESS_KEY" {
  value = aws_iam_access_key.lago_access_key.secret
  sensitive = true
}

output "LAGO_AWS_S3_BUCKET" {
  value = var.s3_bucket
}