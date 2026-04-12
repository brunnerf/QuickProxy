resource "aws_vpc" "proxy" {
  # checkov:skip=CKV2_AWS_12: default SG is unused; traffic is controlled via proxy_sg which has zero inbound rules
  # checkov:skip=CKV2_AWS_11: VPC flow logs incur cost; not required for a free-tier personal proxy project
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, { Name = "proxy-vpc" })
}

resource "aws_subnet" "proxy_public" {
  vpc_id            = aws_vpc.proxy.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 0)
  availability_zone = "${local.aws_region}a"

  tags = merge(local.common_tags, { Name = "proxy-subnet" })
}

resource "aws_internet_gateway" "proxy_igw" {
  vpc_id = aws_vpc.proxy.id

  tags = merge(local.common_tags, { Name = "proxy-igw" })
}

resource "aws_route_table" "proxy_public_rt" {
  vpc_id = aws_vpc.proxy.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.proxy_igw.id
  }

  tags = merge(local.common_tags, { Name = "proxy-rt" })
}

resource "aws_route_table_association" "proxy_public" {
  subnet_id      = aws_subnet.proxy_public.id
  route_table_id = aws_route_table.proxy_public_rt.id
}

resource "aws_security_group" "proxy_sg" {
  # checkov:skip=CKV_AWS_382: Full outbound required for SSM Session Manager endpoints and SOCKS proxy traffic
  name        = "proxy-sg"
  description = "SOCKS proxy security group - no inbound, all outbound"
  vpc_id      = aws_vpc.proxy.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic for SSM Session Manager endpoints and SOCKS proxy"
  }

  tags = merge(local.common_tags, { Name = "proxy-sg" })
}
