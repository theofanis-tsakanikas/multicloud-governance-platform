# The IPsec tunnel joining GCP's AWS transit VPC to the GCP VPC.
#
# It carries exactly one kind of traffic: the BigQuery gateway's TCP 443, from the Fargate task in
# 10.11.0.0/16 to Google's private API VIP (199.36.153.8/30), which the GCP VPC then hands to
# Google's own frontend. Nothing else crosses it.
#
# ── WHY THIS IS ONE TUNNEL AND NOT FOUR ─────────────────────────────────────────────────────────
#
# The previous version built the textbook HA topology: two AWS VPN connections against the two
# interfaces of a GCP HA VPN gateway, four tunnels, four BGP sessions. It also carried a bug that
# would have kept half of them down forever — every tunnel was handed `tunnel1_preshared_key`,
# including the odd ones that terminate on the AWS connection's *second* tunnel, which has a
# different key. The module's own header admitted it had never been validated.
#
# Four tunnels is roughly $219/month for a demo that needs one path to work. This builds a single
# tunnel, the same shape as the Azure bridge that is up right now and carrying Azure SQL. AWS will
# report its second tunnel DOWN: that is expected, not a fault, and it is the price of not paying
# for an HA pair nobody is failing over to.
#
# BGP is not optional — GCP HA VPN has no static-route mode. The Cloud Router exists only to hold
# that session, and to learn 10.11.0.0/16 from AWS so that Google's replies find their way home.

locals {
  gcp_asn = 65534 # GCP's Cloud Router ASN, and what AWS must expect on the peer
}

# ── AWS side ────────────────────────────────────────────────────────────────────────────────────

# The peer, as AWS sees it: interface 0 of the GCP HA VPN gateway.
resource "aws_customer_gateway" "gcp_side" {
  bgp_asn    = local.gcp_asn
  ip_address = var.gcp_vpn_gw_ips[0]
  type       = "ipsec.1"
  tags       = { Name = "cgw-to-gcp" }
}

resource "aws_vpn_connection" "aws_to_gcp" {
  vpn_gateway_id      = var.aws_vpn_gw_id
  customer_gateway_id = aws_customer_gateway.gcp_side.id
  type                = "ipsec.1"
  static_routes_only  = false # HA VPN on the GCP side speaks BGP or it speaks nothing

  tags = { Name = "s2s-to-gcp" }
}

# ── GCP side ────────────────────────────────────────────────────────────────────────────────────

# AWS, as GCP sees it. One address: tunnel 1 of the connection above.
resource "google_compute_external_vpn_gateway" "aws_gw" {
  name            = "external-aws-gateway"
  project         = var.project_id
  redundancy_type = "SINGLE_IP_INTERNALLY_REDUNDANT"
  description     = "The AWS VPN connection's tunnel-1 endpoint"

  interface {
    id         = 0
    ip_address = aws_vpn_connection.aws_to_gcp.tunnel1_address
  }
}

resource "google_compute_router" "gcp_router" {
  name    = "gcp-aws-router"
  project = var.project_id
  region  = var.location
  network = var.gcp_vpc_id

  bgp {
    asn = local.gcp_asn
  }
}

resource "google_compute_vpn_tunnel" "tunnel" {
  name    = "gcp-tunnel-to-aws"
  project = var.project_id
  region  = var.location

  vpn_gateway                     = var.gcp_vpn_gw_id
  vpn_gateway_interface           = 0
  peer_external_gateway           = google_compute_external_vpn_gateway.aws_gw.id
  peer_external_gateway_interface = 0

  # The key AWS generated for tunnel 1. Handing it to a tunnel that terminates on AWS tunnel 2 is
  # precisely the bug that would have left the old module's odd tunnels down forever.
  shared_secret = aws_vpn_connection.aws_to_gcp.tunnel1_preshared_key

  router = google_compute_router.gcp_router.id
}

# The BGP session rides inside the tunnel, on the /30 AWS assigns to it.
resource "google_compute_router_interface" "iface" {
  name       = "interface-to-aws"
  project    = var.project_id
  region     = var.location
  router     = google_compute_router.gcp_router.name
  ip_range   = "${aws_vpn_connection.aws_to_gcp.tunnel1_cgw_inside_address}/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnel.name
}

resource "google_compute_router_peer" "peer" {
  name                      = "peer-to-aws"
  project                   = var.project_id
  region                    = var.location
  router                    = google_compute_router.gcp_router.name
  interface                 = google_compute_router_interface.iface.name
  peer_ip_address           = aws_vpn_connection.aws_to_gcp.tunnel1_vgw_inside_address
  peer_asn                  = aws_vpn_connection.aws_to_gcp.tunnel1_bgp_asn
  advertised_route_priority = 100
}
