resource "aws_vpn_gateway" "vpn_gw" {
  vpc_id = aws_vpc.main.id
  tags   = local.tags
}

resource "aws_customer_gateway" "customer_gateway" {
  bgp_asn    = 65000
  ip_address = var.vpn_customer_gw
  type       = "ipsec.1"
  tags       = local.tags
}

resource "aws_vpn_connection" "main" {
  vpn_gateway_id      = aws_vpn_gateway.vpn_gw.id
  customer_gateway_id = aws_customer_gateway.customer_gateway.id
  type                = "ipsec.1"
  static_routes_only  = true
}

resource "aws_vpn_connection_route" "dc_worker" {
  destination_cidr_block = var.vpn_customer_worker_cidr
  vpn_connection_id      = aws_vpn_connection.main.id
}

resource "aws_vpn_connection_route" "dc_pod" {
  destination_cidr_block = var.vpn_customer_pod_cidr
  vpn_connection_id      = aws_vpn_connection.main.id
}

resource "aws_route" "vpn_worker" {
  route_table_id         = aws_vpc.main.default_route_table_id
  destination_cidr_block = var.vpn_customer_worker_cidr
  gateway_id             = aws_vpn_gateway.vpn_gw.id
}

resource "aws_route" "vpn_pod" {
  route_table_id         = aws_vpc.main.default_route_table_id
  destination_cidr_block = var.vpn_customer_pod_cidr
  gateway_id             = aws_vpn_gateway.vpn_gw.id
}


output "vpn" {
  value     = aws_vpn_connection.main
  sensitive = true
}
