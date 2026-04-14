
# ── EC2 demo instance ─────────────────────────────────────────────────────────

# Latest Amazon Linux 2023 AMI — managed by AWS, always patched
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Use the default VPC so the demo needs no extra networking setup
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security group — no inbound rules at all (no SSH, no HTTP)
# Outbound is open so the instance can reach AWS APIs and pull updates
resource "aws_security_group" "demo" {
  name        = "shipping-iac-demo-${var.environment}"
  description = "Demo EC2 — no inbound access"
  vpc_id      = data.aws_vpc.default.id

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "shipping-iac-demo-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_instance" "demo" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = tolist(data.aws_subnets.default.ids)[0]
  vpc_security_group_ids = [aws_security_group.demo.id]

  # No key pair — SSH access is intentionally disabled
  key_name = null

  # Disable instance metadata service v1 (IMDSv2 only — security best practice)
  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = {
    Name        = "shipping-iac-demo-${var.environment}"
    Environment = var.environment
  }
}

