
# Jump Host Instance
resource "oci_core_instance" "jump_host" {
  compartment_id = oci_identity_compartment.wis_compartment.id
  display_name   = "jump-host"
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  shape          = var.compute_shape

  
  #shape_config {
  #  ocpus         = var.ocpus
  #  memory_in_gbs = var.memory_in_gbs
  #}

  create_vnic_details {
    subnet_id = oci_core_subnet.frontend_subnet.id
    nsg_ids   = [oci_core_network_security_group.jump_host_nsg.id]
    assign_public_ip = false
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.oracle_linux.images[0].id
  }

  metadata = {
    ssh_authorized_keys = trimspace(file(var.ssh_public_key_path))

  }
  

  depends_on = [
    oci_core_subnet.frontend_subnet,
    oci_core_network_security_group.jump_host_nsg
  ]
}

# Frontend Instance
resource "oci_core_instance" "frontend_instance" {
  compartment_id = oci_identity_compartment.wis_compartment.id
  display_name   = "frontend-instance"
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  #shape          =  var.compute_shape
  shape          = "VM.Standard.E3.Flex"
  shape_config {
    ocpus         = 2
    memory_in_gbs = 4
  }

  create_vnic_details {
    subnet_id = oci_core_subnet.frontend_subnet.id
    nsg_ids   = [oci_core_network_security_group.frontend_nsg.id]
    assign_public_ip = false
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.oracle_linux.images[0].id
  }

  metadata = {
    ssh_authorized_keys = trimspace(file(var.ssh_public_key_path))
  }

  depends_on = [
    oci_core_subnet.frontend_subnet,
    oci_core_network_security_group.frontend_nsg
  ]
}

# Backend Instance
resource "oci_core_instance" "backend_instance" {
  compartment_id = oci_identity_compartment.wis_compartment.id
  display_name   = "backend-instance"
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  shape          = "VM.Standard.E3.Flex"

  shape_config {
    ocpus         = 2
    memory_in_gbs = 4
  }

  create_vnic_details {
    subnet_id = oci_core_subnet.backend_subnet.id
    nsg_ids   = [oci_core_network_security_group.backend_nsg.id]
    assign_public_ip = false
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.V2_oracle_linux.images[0].id
  }

  metadata = {
    ssh_authorized_keys = trimspace(file(var.ssh_public_key_path))
  }

  depends_on = [
    oci_core_subnet.backend_subnet,
    oci_core_network_security_group.backend_nsg
  ]
}

# Database Instance
resource "oci_core_instance" "db_instance" {
  compartment_id = oci_identity_compartment.wis_compartment.id
  display_name   = "db-instance"
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  shape          = "VM.Standard.E3.Flex"

  shape_config {
    ocpus         = 2
    memory_in_gbs = 4
  }

  create_vnic_details {
    subnet_id = oci_core_subnet.db_subnet.id
    nsg_ids   = [oci_core_network_security_group.db_nsg.id]
    assign_public_ip = false
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.V2_oracle_linux.images[0].id
  }

  metadata = {
    ssh_authorized_keys = trimspace(file(var.ssh_public_key_path))
  }

  depends_on = [
    oci_core_subnet.db_subnet,
    oci_core_network_security_group.db_nsg,
    oci_core_instance.backend_instance
  ]
}


# Public Load Balancer
resource "oci_load_balancer_load_balancer" "public_lb" {
  compartment_id = oci_identity_compartment.wis_compartment.id
  display_name   = "WIS-Public-LB"
  count = var.enable_load_balancer ? 1 : 0
  shape          = "flexible"

  subnet_ids = [oci_core_subnet.lb_subnet.id]
  network_security_group_ids = [oci_core_network_security_group.lb_nsg.id]

  shape_details {
    minimum_bandwidth_in_mbps = 10
    maximum_bandwidth_in_mbps = 20
  }

  depends_on = [
    oci_core_subnet.lb_subnet,
    oci_core_network_security_group.lb_nsg
  ]
}


# Load Balancer Backend Set - Vote Service (8080)
resource "oci_load_balancer_backend_set" "vote_backend_set" {
  name             = "vote-backend-set"
  count            = var.enable_load_balancer ? 1 : 0
  load_balancer_id = oci_load_balancer_load_balancer.public_lb[0].id
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol = "HTTP"
    port     = 8080
    url_path = "/"
  }

  depends_on = [oci_load_balancer_load_balancer.public_lb]
}

# Load Balancer Backend Set - Result Service (8081)
resource "oci_load_balancer_backend_set" "result_backend_set" {
  name             = "result-backend-set"
  count            = var.enable_load_balancer ? 1 : 0
  load_balancer_id = oci_load_balancer_load_balancer.public_lb[0].id
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol = "HTTP"
    port     = 8081
    url_path = "/"
  }

  depends_on = [oci_load_balancer_load_balancer.public_lb]
}

# Load Balancer Backend - Vote Service
resource "oci_load_balancer_backend" "vote_backend" {
  count            = var.enable_load_balancer ? 1 : 0
  load_balancer_id = oci_load_balancer_load_balancer.public_lb[0].id
  backendset_name  = oci_load_balancer_backend_set.vote_backend_set[0].name
  ip_address       = oci_core_instance.frontend_instance.private_ip
  port             = 8080
  weight           = 1

  depends_on = [
    oci_core_instance.frontend_instance,
    oci_load_balancer_backend_set.vote_backend_set[0]
  ]
}

# Load Balancer Backend - Result Service
resource "oci_load_balancer_backend" "result_backend" {
  count            = var.enable_load_balancer ? 1 : 0
  load_balancer_id = oci_load_balancer_load_balancer.public_lb[0].id
  backendset_name  = oci_load_balancer_backend_set.result_backend_set[0].name
  ip_address       = oci_core_instance.frontend_instance.private_ip
  port             = 8081
  weight           = 1

  depends_on = [
    oci_core_instance.frontend_instance,
    oci_load_balancer_backend_set.result_backend_set[0]
  ]
}

# Path-based Routing Policy
resource "oci_load_balancer_path_route_set" "path_routes" {
  count            = var.enable_load_balancer ? 1 : 0
  load_balancer_id = oci_load_balancer_load_balancer.public_lb[0].id
  name             = "path-routing"

  path_routes {
    backend_set_name = oci_load_balancer_backend_set.vote_backend_set[0].name
    path             = "/vote"
    path_match_type {
      match_type = "PREFIX_MATCH"
    }
  }

  path_routes {
    backend_set_name = oci_load_balancer_backend_set.result_backend_set[0].name
    path             = "/result"
    path_match_type {
      match_type = "PREFIX_MATCH"
    }
  }

  depends_on = [
    oci_load_balancer_backend_set.vote_backend_set,
    oci_load_balancer_backend_set.result_backend_set
  ]
}

# Load Balancer Listener with Path-based Routing
resource "oci_load_balancer_listener" "http_listener" {
  count                    = var.enable_load_balancer ? 1 : 0
  load_balancer_id         = oci_load_balancer_load_balancer.public_lb[0].id
  name                     = "http-listener"
  default_backend_set_name = oci_load_balancer_backend_set.vote_backend_set[0].name
  port                     = 80
  protocol                 = "HTTP"
  path_route_set_name      = oci_load_balancer_path_route_set.path_routes[0].name

  depends_on = [
    oci_load_balancer_backend_set.vote_backend_set[0],
    oci_load_balancer_path_route_set.path_routes[0]
  ]
}

# OCI Bastion
resource "oci_bastion_bastion" "wis_bastion" {
  compartment_id = oci_identity_compartment.wis_compartment.id
  name   = "WIS-Bastion"
  target_subnet_id      = oci_core_subnet.bastion_subnet.id
  bastion_type   = "STANDARD"
  client_cidr_block_allow_list = ["0.0.0.0/0"]
  
  depends_on = [
    oci_core_subnet.bastion_subnet
  ]
}


# Bastion Session to Jump Host ,then access this session to ssh to other private tiers
# to be opend while the need of direct access after provisioning
# and to create a session u could do that with help of outputs.tf via "bastion_session_command"


# resource "oci_bastion_session" "jump_host_session" {
#   bastion_id  = oci_bastion_bastion.wis_bastion.id
#   display_name = "jump-host-session-by-TF-apply"
  
#   target_resource_details {
#     target_resource_id = oci_core_instance.jump_host.id
#     target_resource_port = 22
#     session_type = "PORT_FORWARDING"
#     target_resource_private_ip_address = oci_core_instance.jump_host.private_ip
#   } 
    
#     key_details {
#     public_key_content = trimspace(file(var.ssh_public_key_path))
    
#   }

#   session_ttl_in_seconds = 10800

#   depends_on = [
#     oci_bastion_bastion.wis_bastion,
#     oci_core_instance.jump_host
#   ]
# }