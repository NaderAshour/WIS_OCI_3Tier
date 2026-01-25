# Bastion NSG

resource "oci_core_network_security_group" "bastion_nsg" {
  compartment_id = oci_identity_compartment.wis_compartment.id
  vcn_id         = oci_core_virtual_network.vcn.id
  display_name   = "Bastion-NSG"

  depends_on = [
    oci_core_virtual_network.vcn
  ]
}

# SSH from Internet to Bastion
resource "oci_core_network_security_group_security_rule" "bastion_ssh_ingress" {
  network_security_group_id = oci_core_network_security_group.bastion_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6"

  source      = "0.0.0.0/0"
  source_type = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }

  description = "SSH from Internet"
}

# Bastion outbound
resource "oci_core_network_security_group_security_rule" "bastion_egress_all" {
  network_security_group_id = oci_core_network_security_group.bastion_nsg.id
  direction                 = "EGRESS"
  protocol                  = "all"

  destination      = "0.0.0.0/0"
  destination_type = "CIDR_BLOCK"

  description = "Outbound traffic"
}

# Jump Host NSG

resource "oci_core_network_security_group" "jump_host_nsg" {
  compartment_id = oci_identity_compartment.wis_compartment.id
  vcn_id         = oci_core_virtual_network.vcn.id
  display_name   = "Jump-Host-NSG"
  depends_on = [
    oci_core_virtual_network.vcn
  ]
}

# SSH from Bastion
resource "oci_core_network_security_group_security_rule" "jump_ssh_from_bastion" {
  network_security_group_id = oci_core_network_security_group.jump_host_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6"

  source      = oci_core_network_security_group.bastion_nsg.id
  source_type = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }

  description = "SSH from Bastion"
}

# Access to private tiers
resource "oci_core_network_security_group_security_rule" "jump_egress_private" {
  network_security_group_id = oci_core_network_security_group.jump_host_nsg.id
  direction                 = "EGRESS"
  protocol                  = "all"

  destination      = "10.0.0.0/16"
  destination_type = "CIDR_BLOCK"

  description = "Access to all private tiers"
}

# Load Balancer NSG
resource "oci_core_network_security_group" "lb_nsg" {
  compartment_id = oci_identity_compartment.wis_compartment.id
  vcn_id         = oci_core_virtual_network.vcn.id
  display_name   = "LB-NSG"
  depends_on = [
    oci_core_virtual_network.vcn
  ]
}

# access to HTTP
resource "oci_core_network_security_group_security_rule" "lb_http_ingress" {
  network_security_group_id = oci_core_network_security_group.lb_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6"

  source      = "0.0.0.0/0"
  source_type = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 80
      max = 80
    }
  }

  description = "HTTP from Internet"
}

# access to HTTPS
resource "oci_core_network_security_group_security_rule" "lb_https_ingress" {
  network_security_group_id = oci_core_network_security_group.lb_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6"

  source      = "0.0.0.0/0"
  source_type = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }

  description = "HTTPS from Internet"
}

# Forward to Frontend
resource "oci_core_network_security_group_security_rule" "lb_to_frontend" {
  network_security_group_id = oci_core_network_security_group.lb_nsg.id
  direction                 = "EGRESS"
  protocol                  = "6"

  destination      = oci_core_network_security_group.frontend_nsg.id
  destination_type = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = 8080
      max = 8081
    }
  }

  description = "Forward traffic to Frontend"
}

# Frontend NSG
resource "oci_core_network_security_group" "frontend_nsg" {
  compartment_id = oci_identity_compartment.wis_compartment.id
  vcn_id         = oci_core_virtual_network.vcn.id
  display_name   = "Frontend-NSG"
  depends_on = [
    oci_core_virtual_network.vcn
  ]
}

# From LB
resource "oci_core_network_security_group_security_rule" "frontend_from_lb" {
  network_security_group_id = oci_core_network_security_group.frontend_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6"

  source      = oci_core_network_security_group.lb_nsg.id
  source_type = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = 8080
      max = 8081
    }
  }

  description = "HTTP from Load Balancer"
}

# SSH from Jump Host
resource "oci_core_network_security_group_security_rule" "frontend_ssh_jump" {
  network_security_group_id = oci_core_network_security_group.frontend_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6"

  source      = oci_core_network_security_group.jump_host_nsg.id
  source_type = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }

  description = "SSH from Jump Host"
}

# To Backend (API)
resource "oci_core_network_security_group_security_rule" "frontend_to_backend" {
  network_security_group_id = oci_core_network_security_group.frontend_nsg.id
  direction                 = "EGRESS"
  protocol                  = "6"

  destination      = oci_core_network_security_group.backend_nsg.id
  destination_type = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = 8080
      max = 8080
    }
  }

  description = "API calls to Backend"
}

# To Backend (Redis)
resource "oci_core_network_security_group_security_rule" "frontend_to_backend_redis" {
  network_security_group_id = oci_core_network_security_group.frontend_nsg.id
  direction                 = "EGRESS"
  protocol                  = "6"

  destination      = oci_core_network_security_group.backend_nsg.id
  destination_type = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = 6379
      max = 6379
    }
  }

  description = "Redis connections to Backend"
}

# Internet through NAT
resource "oci_core_network_security_group_security_rule" "frontend_egress_internet" {
  network_security_group_id = oci_core_network_security_group.frontend_nsg.id
  direction                 = "EGRESS"
  protocol                  = "6"

  destination      = "0.0.0.0/0"
  destination_type = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }

  description = "Outbound internet via NAT"
}

# To Database (PostgreSQL) - for Result service
resource "oci_core_network_security_group_security_rule" "frontend_to_db" {
  network_security_group_id = oci_core_network_security_group.frontend_nsg.id
  direction                 = "EGRESS"
  protocol                  = "6"

  destination      = oci_core_network_security_group.db_nsg.id
  destination_type = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = 5432
      max = 5432
    }
  }

  description = "PostgreSQL connections for Result service"
}

# Backend NSG
resource "oci_core_network_security_group" "backend_nsg" {
  compartment_id = oci_identity_compartment.wis_compartment.id
  vcn_id         = oci_core_virtual_network.vcn.id
  display_name   = "Backend-NSG"
  depends_on = [
    oci_core_virtual_network.vcn
  ]
}

# From Frontend (API)
resource "oci_core_network_security_group_security_rule" "backend_from_frontend" {
  network_security_group_id = oci_core_network_security_group.backend_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6"

  source      = oci_core_network_security_group.frontend_nsg.id
  source_type = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = 8080
      max = 8080
    }
  }

  description = "Requests from Frontend"
}

# From Frontend (Redis)
resource "oci_core_network_security_group_security_rule" "backend_from_frontend_redis" {
  network_security_group_id = oci_core_network_security_group.backend_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6"

  source      = oci_core_network_security_group.frontend_nsg.id
  source_type = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = 6379
      max = 6379
    }
  }

  description = "Redis connections from Frontend"
}

# SSH from Jump Host
resource "oci_core_network_security_group_security_rule" "backend_ssh_jump" {
  network_security_group_id = oci_core_network_security_group.backend_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6"

  source      = oci_core_network_security_group.jump_host_nsg.id
  source_type = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }

  description = "SSH from Jump Host"
}

# To DB (PostgreSQL)
resource "oci_core_network_security_group_security_rule" "backend_to_db" {
  network_security_group_id = oci_core_network_security_group.backend_nsg.id
  direction                 = "EGRESS"
  protocol                  = "6"

  destination      = oci_core_network_security_group.db_nsg.id
  destination_type = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = 5432
      max = 5432
    }
  }

  description = "PostgreSQL connections"
}

# Database NSG
resource "oci_core_network_security_group" "db_nsg" {
  compartment_id = oci_identity_compartment.wis_compartment.id
  vcn_id         = oci_core_virtual_network.vcn.id
  display_name   = "DB-NSG"
  depends_on = [
    oci_core_virtual_network.vcn
  ]
}

# From Backend (PostgreSQL)
resource "oci_core_network_security_group_security_rule" "db_from_backend" {
  network_security_group_id = oci_core_network_security_group.db_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6"

  source      = oci_core_network_security_group.backend_nsg.id
  source_type = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = 5432
      max = 5432
    }
  }

  description = "PostgreSQL access from Backend"
}

# From Frontend (PostgreSQL) - for Result service
resource "oci_core_network_security_group_security_rule" "db_from_frontend" {
  network_security_group_id = oci_core_network_security_group.db_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6"

  source      = oci_core_network_security_group.frontend_nsg.id
  source_type = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = 5432
      max = 5432
    }
  }

  description = "PostgreSQL access from Frontend (Result service)"
}

# SSH from Jump Host
resource "oci_core_network_security_group_security_rule" "db_ssh_jump" {
  network_security_group_id = oci_core_network_security_group.db_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6"

  source      = oci_core_network_security_group.jump_host_nsg.id
  source_type = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }

  description = "SSH from Jump Host"
}
