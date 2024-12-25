data "aws_availability_zones" "available" {}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  instance_tenancy     = "default"
  tags                 = local.tags
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  route {
    cidr_block = var.vpc_cidr
    gateway_id = "local"
  }

  tags = {
    Name = "public"
  }
}

resource "aws_subnet" "public_subnets" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.public_subnet_cidrs, count.index)
  availability_zone = element(local.azs, count.index)
  tags = {
    Name = "Public Subnet ${count.index + 1}"
  }
}

resource "aws_route_table_association" "public" {
  for_each       = { for i, v in aws_subnet.public_subnets : i => v }
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat_gateway" {}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat_gateway.id
  subnet_id     = aws_subnet.public_subnets[0].id
  tags = {
    Name = "gw NAT"
  }
  depends_on = [aws_internet_gateway.main]
}


resource "aws_subnet" "private_subnets" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.private_subnet_cidrs, count.index)
  availability_zone = element(local.azs, count.index)
  tags = {
    Name                                        = "Private Subnet ${count.index + 1}"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

resource "aws_route" "nat" {
  route_table_id         = aws_vpc.main.default_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}