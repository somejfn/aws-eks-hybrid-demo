resource "aws_route53_zone" "private" {
  count = var.enable_private_ingress_zone == true ? 1 : 0
  name  = var.private_ingress_zone_domain

  vpc {
    vpc_id = aws_vpc.main.id
  }
}

resource "aws_security_group" "inbound_dns" {
  count       = var.enable_private_ingress_zone == true ? 1 : 0
  name        = "allow_inbound_dns"
  description = "Allow DNS inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "DNS from internal"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr, var.vpn_customer_worker_cidr]
  }

  ingress {
    description = "DNS from internal"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr, var.vpn_customer_worker_cidr]
  }

  tags = {
    Name = "inbound_dns"
  }
}

resource "aws_route53_resolver_endpoint" "inbound" {
  count     = var.enable_private_ingress_zone == true ? 1 : 0
  name      = "inbound"
  direction = "INBOUND"

  security_group_ids = [aws_security_group.inbound_dns[0].id]

  dynamic "ip_address" {
    for_each = aws_subnet.private_subnets[*].id
    content {
      subnet_id = ip_address.value
    }
  }
  tags = {
    Name = "inbound_dns"
  }
}

