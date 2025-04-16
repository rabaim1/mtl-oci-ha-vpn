terraform {
  backend "gcs" {
    bucket = "cision-terraform-devops"
    prefix = "network/vpn/dev/oci-ha-vpn"
  }
}

provider "google" {
  project = "global-dev-project-011"
}

locals {
  shared_project = "global-dev-project-011"
  secrets_project = "global-dev-project-011"
  network = "shared-vpc-network"
  region  = "northamerica-northeast1"
  ssl_cision-oci_key-1_secret  = "key-cision-oci-1"
  ssl_cision-oci_key-2_secret  = "key-cision-oci-2"
}

# Dev VPC network
data "google_compute_network" "dev_shared_vpc" {
  name    = local.network
  project = local.shared_project
}

# OCI-US router
data "google_compute_router" "gcp-oci-ca-router" {
  name    = "gcp-oci-ca-router"
  network = data.google_compute_network.dev_shared_vpc.id
  region  = local.region
  project = local.shared_project
}

data "google_secret_manager_secret_version" "cision-oci-key-1" {
  secret  = local.ssl_cision-oci_key-1_secret
  project = local.secrets_project
}
data "google_secret_manager_secret_version" "cision-oci-key-2" {
  secret  = local.ssl_cision-oci_key-2_secret
  project = local.secrets_project
}
resource "google_compute_vpn_tunnel" "tunnel-oci-to-oracle-cloud-if-0" {
  name                            =  "tunnel-oci-to-oracle-cloud-if-0"
# peer_ip                         = google_compute_external_vpn_gateway.oci-peer-gw.interface[0].ip_address
  project                         = data.google_compute_network.dev_shared_vpc.project
  region                          = local.region
  shared_secret                   = data.google_secret_manager_secret_version.cision-oci-key-1.secret_data
  peer_external_gateway           = google_compute_external_vpn_gateway.oci-peer-gw.id
  peer_external_gateway_interface = 0
  router                          = data.google_compute_router.gcp-oci-ca-router.id
  vpn_gateway                     = google_compute_ha_vpn_gateway.oci-ha-vpn-gw.self_link
  vpn_gateway_interface           = 0
  timeouts {}
}
# terraform import google_compute_vpn_tunnel.tunnel-oci-to-on-prem-if-0 projects/global-dev-project-011/regions/us-east4/vpnTunnels/tunnel-oci-cloud-0
# terraform state rm google_compute_vpn_tunnel.tunnel-oci-cloud-0

resource "google_compute_vpn_tunnel" "tunnel-oci-to-oracle-cloud-if-1" {
  name                            =  "tunnel-oci-to-oracle-cloud-if-1"
  project                         = data.google_compute_network.dev_shared_vpc.project
  region                          = local.region
# peer_ip                         = google_compute_external_vpn_gateway.oci-peer-gw.interface[1].ip_address
  shared_secret                   = data.google_secret_manager_secret_version.cision-oci-key-2.secret_data
  peer_external_gateway           = google_compute_external_vpn_gateway.oci-peer-gw.id
  peer_external_gateway_interface = 1
  router                          = data.google_compute_router.gcp-oci-ca-router.id
  vpn_gateway                     = google_compute_ha_vpn_gateway.oci-ha-vpn-gw.self_link
  vpn_gateway_interface           = 1
  timeouts {}
}
# terraform import google_compute_vpn_tunnel.tunnel-oci-to-on-prem-if-1 projects/global-dev-project-011/regions/us-east4/vpnTunnels/tunnel-oci-cloud-1
# terraform state rm google_compute_vpn_tunnel.tunnel-oci-cloud-1

resource "google_compute_ha_vpn_gateway" "oci-ha-vpn-gw" {
  name    = "oci-ha-vpn-gw"
  network = data.google_compute_network.dev_shared_vpc.id
  region  = local.region
  project = local.shared_project
}
# terraform import google_compute_ha_vpn_gateway.oci-ha-vpn-gw projects/global-dev-project-011/regions/us-east4/vpnGateways/oci-ha-vpn-gw
# terraform state rm google_compute_ha_vpn_gateway.oci-ha-vpn-gw

resource "google_compute_external_vpn_gateway" "oci-peer-gw" {
  name            = "oci-peer-gw"
  project         = local.shared_project
  redundancy_type = "TWO_IPS_REDUNDANCY"
  interface {
    id         = 0
    ip_address = "168.138.65.78"
  }
  interface {
    id         = 1
    ip_address = "168.138.64.58"
  }
}
# terraform import google_compute_external_vpn_gateway.oci-peer-gw projects/global-dev-project-011/global/externalVpnGateways/oci-peer-gw
# terraform state rm google_compute_external_vpn_gateway.oci-peer-gw


#########Configuring Setting for a BGP##############

resource "google_compute_router_interface" "router1_interface1" {
name = "router1-interface1"
router= data.google_compute_router.gcp-oci-ca-router.name
region  = local.region
ip_range = "169.254.143.173/30"
}

resource "google_compute_router_peer" "router1_peer1" {
name = "bgp-oci-to-gcp3"
router= data.google_compute_router.gcp-oci-ca-router.id
region  = local.region
peer_asn = 31898
peer_ip_address = "169.254.143.174"
advertised_route_priority = 110
interface = google_compute_router_interface.router1_interface1.name
}
resource "google_compute_router_interface" "router1_interface2" {
name = "router1-interface2"
router= data.google_compute_router.gcp-oci-ca-router.name
region  = local.region
ip_range = "169.254.67.121/30"
}

resource "google_compute_router_peer" "router1_peer2" {
name = "bgp-oci-to-gcp4"
router= data.google_compute_router.gcp-oci-ca-router.id
region  = local.region
peer_asn = 31898
peer_ip_address = "169.254.67.122"
advertised_route_priority = 120
interface = google_compute_router_interface.router1_interface2.name
}
