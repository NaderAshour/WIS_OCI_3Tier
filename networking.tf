# VCN
resource "oci_core_virtual_network" "vcn" {
  compartment_id = oci_identity_compartment.wis_compartment.id
  display_name   = "WIS_3Tier_VCN"
  cidr_block     = "10.0.0.0/16"
  dns_label      = "wisvcn"
  depends_on     = [oci_identity_compartment.wis_compartment]
}

# Internet Gateway

resource "oci_core_internet_gateway" "igw" {
  compartment_id = oci_identity_compartment.wis_compartment.id
  vcn_id         = oci_core_virtual_network.vcn.id
  display_name   = "WIS-Internet-Gateway"

  depends_on = [
    oci_core_virtual_network.vcn
  ]
}

# NAT Gateway

resource "oci_core_nat_gateway" "nat_gw" {
  compartment_id = oci_identity_compartment.wis_compartment.id
  vcn_id         = oci_core_virtual_network.vcn.id
  display_name   = "WIS-NAT-Gateway"

  depends_on = [
    oci_core_virtual_network.vcn
  ]
}


# Public Route Table
resource "oci_core_route_table" "public_rt" {
  compartment_id = oci_identity_compartment.wis_compartment.id
  vcn_id         = oci_core_virtual_network.vcn.id
  display_name   = "Public-Route-Table"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.igw.id
  }

  depends_on = [
    oci_core_internet_gateway.igw
  ]
}


# Private Route Table
resource "oci_core_route_table" "private_rt" {
  compartment_id = oci_identity_compartment.wis_compartment.id
  vcn_id         = oci_core_virtual_network.vcn.id
  display_name   = "Private-Route-Table"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.nat_gw.id
  }

  depends_on = [
    oci_core_nat_gateway.nat_gw
  ]
}

# Load Balancer Subnet (Public)

resource "oci_core_subnet" "lb_subnet" {
  compartment_id             = oci_identity_compartment.wis_compartment.id
  vcn_id                     = oci_core_virtual_network.vcn.id
  display_name               = "LB-Subnet"
  cidr_block                 = "10.0.1.0/24"
  dns_label                  = "lbsubnet"
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_route_table.public_rt.id
}


# Frontend Subnet (Private)

resource "oci_core_subnet" "frontend_subnet" {
  compartment_id             = oci_identity_compartment.wis_compartment.id
  vcn_id                     = oci_core_virtual_network.vcn.id
  display_name               = "Frontend-Subnet"
  cidr_block                 = "10.0.2.0/24"
  dns_label                  = "frontendsubnet"
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.private_rt.id
}


# Backend Subnet (Private)

resource "oci_core_subnet" "backend_subnet" {
  compartment_id             = oci_identity_compartment.wis_compartment.id
  vcn_id                     = oci_core_virtual_network.vcn.id
  display_name               = "Backend-Subnet"
  cidr_block                 = "10.0.3.0/24"
  dns_label                  = "backendsubnet"
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.private_rt.id
}

# Database Subnet (Private)
resource "oci_core_subnet" "db_subnet" {
  compartment_id             = oci_identity_compartment.wis_compartment.id
  vcn_id                     = oci_core_virtual_network.vcn.id
  display_name               = "DB-Subnet"
  cidr_block                 = "10.0.4.0/24"
  dns_label                  = "dbsubnet"
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.private_rt.id
}

# Bastion Subnet (Public)
resource "oci_core_subnet" "bastion_subnet" {
  compartment_id             = oci_identity_compartment.wis_compartment.id
  vcn_id                     = oci_core_virtual_network.vcn.id
  display_name               = "Bastion-Subnet"
  cidr_block                 = "10.0.5.0/24"
  dns_label                  = "bastionsubnet"
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_route_table.public_rt.id
}
