# 1. The VPC in GCP
resource "google_compute_network" "gcp_vpc" {
  name = var.network_name
  # Disables automatic subnet creation for manual control over CIDR ranges
  auto_create_subnetworks = false
  project                 = var.project_id
}

# 2. The Subnet with Private Google Access (Equivalent to AWS Endpoints)
resource "google_compute_subnetwork" "gcp_subnet" {
  name          = var.subnetwork_name
  ip_cidr_range = var.gcp_subnet_cidr
  region        = var.location
  network       = google_compute_network.gcp_vpc.id

  # Crucial: Allows resources in this subnet to reach Google APIs (like BigQuery) 
  # without needing a Public IP or Internet Gateway.
  private_ip_google_access = true
}

# 3. Firewall to allow inbound traffic from the AWS environment
resource "google_compute_firewall" "allow_aws_traffic" {
  name    = "allow-aws-databricks-traffic"
  network = google_compute_network.gcp_vpc.name

  allow {
    protocol = "tcp"
    # Ports for BigQuery APIs and common database connections (MySQL/Postgres)
    ports = ["443", "3306", "5432"]
  }

  # Whitelists the CIDR range of the AWS VPC created in previous steps
  source_ranges = [var.databricks_vpc_cidr]
}

# 4. Google's High Availability (HA) VPN Gateway
resource "google_compute_ha_vpn_gateway" "gcp_vpn_gw" {
  count = var.is_private_connection ? 1 : 0

  name    = var.vpn_gw_name
  network = google_compute_network.gcp_vpc.id
  region  = var.location
}

# ── THE ROUTE THAT MAKES THE WHOLE PATH WORK ────────────────────────────────────────────────────
#
# Traffic for Google's private API VIP arrives here over the VPN, from the BigQuery gateway in the
# AWS transit VPC. Without this route the GCP VPC has nowhere to send it and the packet is dropped
# — the design's single largest hole, and invisible until you trace a connection that simply never
# answers.
#
# `default-internet-gateway` is not what it sounds like. For 199.36.153.8/30 it does not leave for
# the internet: it hands the packet to Google's own private API frontend, which is the entire point
# of the VIP. This is Google's documented pattern for reaching its APIs privately from a network
# joined by VPN or Interconnect.
#
# There is deliberately NO private DNS zone here. Nothing in this path resolves a name inside GCP:
# the gateway dials the VIP by address, and the TLS SNI the Databricks client sent
# (bigquery.googleapis.com, oauth2.googleapis.com …) is what Google's frontend routes on. A DNS
# zone would be a second thing to be wrong, and it would drag in dns.googleapis.com, which this
# project does not enable.
resource "google_compute_route" "private_api_vip" {
  count = var.is_private_connection ? 1 : 0

  name             = "private-googleapis-vip"
  project          = var.project_id
  network          = google_compute_network.gcp_vpc.name
  dest_range       = var.private_api_vip_cidr
  next_hop_gateway = "default-internet-gateway"
  priority         = 100

  description = "Hands private.googleapis.com traffic arriving over the VPN to Google's private API frontend"
}
