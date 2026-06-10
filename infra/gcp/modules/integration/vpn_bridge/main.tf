# --- AWS SIDE ---

# 1. Customer Gateway in AWS
# This represents the GCP side of the VPN connection within AWS
resource "aws_customer_gateway" "gcp_side" {
  # Dynamic count based on the number of public IPs provided by GCP
  count = length(var.gcp_vpn_gw_ips)

  bgp_asn    = 65000 # GCP's ASN
  ip_address = var.gcp_vpn_gw_ips[count.index]
  type       = "ipsec.1"
  tags       = { Name = "cgw-to-gcp-${count.index}" }
}

# 2. VPN Connection in AWS
# Creates the actual IPsec connection between the AWS VGW and the GCP Customer Gateway
resource "aws_vpn_connection" "aws_to_gcp" {
  # Map each Customer Gateway to its own VPN Connection
  count = length(aws_customer_gateway.gcp_side)

  vpn_gateway_id      = var.aws_vpn_gw_id
  customer_gateway_id = aws_customer_gateway.gcp_side[count.index].id
  type                = "ipsec.1"
  # Set to false to enable BGP (Dynamic Routing)
  static_routes_only = false

  tags = { Name = "s2s-to-gcp-${count.index}" }
}

# --- GCP SIDE ---

# 3. Cloud Router (Required for BGP/Dynamic Routing in GCP)
resource "google_compute_router" "gcp_router" {
  name    = "gcp-aws-router"
  network = var.gcp_vpc_id
  region  = var.location
  bgp {
    asn = 65000 # Google's ASN
  }
}

# 4. External VPN Gateway (Declaration of AWS Public IPs in GCP)
resource "google_compute_external_vpn_gateway" "aws_gw" {
  name = "external-aws-gateway"
  # Uses FOUR_IP_REDUNDANCY for 2 connections (4 tunnels total) 
  # or TWO_IP_REDUNDANCY for 1 connection (2 tunnels)
  redundancy_type = length(aws_vpn_connection.aws_to_gcp) > 1 ? "FOUR_IP_REDUNDANCY" : "TWO_IP_REDUNDANCY"

  description = "VPN Gateway pointing to AWS"

  # Local helper to flatten all public IPs from both tunnels of all AWS VPN connections
  locals {
    aws_ips = flatten([
      for conn in aws_vpn_connection.aws_to_gcp : [conn.tunnel1_address, conn.tunnel2_address]
    ])
  }

  # Dynamic block that registers each AWS public IP to a GCP interface
  dynamic "interface" {
    for_each = local.aws_ips
    content {
      id         = interface.key # The index (0, 1, 2, 3...)
      ip_address = interface.value
    }
  }
}

# 5. VPN Tunnels (GCP Side)
# Provisioning 2 tunnels for every AWS VPN Connection to ensure High Availability
resource "google_compute_vpn_tunnel" "tunnels" {
  count                           = length(local.aws_ips)
  name                            = "gcp-tunnel-${count.index}"
  region                          = var.location
  vpn_gateway                     = var.gcp_ha_vpn_gw_id # ID from the network module
  peer_external_gateway           = google_compute_external_vpn_gateway.aws_gw.id
  peer_external_gateway_interface = count.index
  shared_secret                   = aws_vpn_connection.aws_to_gcp[floor(count.index / 2)].tunnel1_preshared_key
  # Note: In production, consider using fixed keys or pulling from a Secret Manager

  router = google_compute_router.gcp_router.name

  # Connect to the correct HA VPN Gateway interface (0 or 1)
  vpn_gateway_interface = count.index % 2
}

# 6. BGP Interfaces & Peers
# This is where the routing "handshake" occurs between AWS and GCP
resource "google_compute_router_interface" "interfaces" {
  count  = length(local.aws_ips)
  name   = "interface-${count.index}"
  router = google_compute_router.gcp_router.name
  region = var.location
  # Assigns the BGP IP range for the GCP side of the tunnel
  ip_range   = count.index % 2 == 0 ? "${aws_vpn_connection.aws_to_gcp[floor(count.index / 2)].tunnel1_cgw_inside_address}/30" : "${aws_vpn_connection.aws_to_gcp[floor(count.index / 2)].tunnel2_cgw_inside_address}/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnels[count.index].name
}

resource "google_compute_router_peer" "peers" {
  count  = length(local.aws_ips)
  name   = "peer-${count.index}"
  router = google_compute_router.gcp_router.name
  region = var.location
  # Targets the peer IP (AWS side) for the BGP session
  peer_ip_address = count.index % 2 == 0 ? aws_vpn_connection.aws_to_gcp[floor(count.index / 2)].tunnel1_vgw_inside_address : aws_vpn_connection.aws_to_gcp[floor(count.index / 2)].tunnel2_vgw_inside_address
  peer_asn        = 64512 # Default AWS ASN
  interface       = google_compute_router_interface.interfaces[count.index].name
}