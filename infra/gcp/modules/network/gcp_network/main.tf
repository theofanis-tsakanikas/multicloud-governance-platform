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
  name    = var.vpn_gw_name
  network = google_compute_network.gcp_vpc.id
  region  = var.location
}



# 5. Private DNS Zone for Google APIs
# Forces traffic to googleapis.com to stay within the Google network
resource "google_dns_managed_zone" "googleapis" {
  name        = "googleapis-private-zone"
  dns_name    = "googleapis.com."
  description = "Private zone for Google APIs"
  project     = var.project_id

  visibility {
    networks {
      network_url = google_compute_network.gcp_vpc.id
    }
  }
}

# Route all Google API calls to the Restricted IP range (Restricted VIP)
resource "google_dns_record_set" "restricted_apis" {
  name         = "*.googleapis.com."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.googleapis.name
  # Standard Restricted VIP addresses for Google Cloud
  rrdatas = ["199.36.153.4", "199.36.153.5", "199.36.153.6", "199.36.153.7"]
}

resource "google_dns_record_set" "cname_googleapis" {
  name         = "googleapis.com."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.googleapis.name
  rrdatas      = ["199.36.153.4", "199.36.153.5", "199.36.153.6", "199.36.153.7"]
}