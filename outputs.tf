output "vcn_id" {
  value = oci_core_virtual_network.vcn.id
}

output "load_balancer_public_ip" {
  value = oci_load_balancer_load_balancer.public_lb.ip_address_details[0].ip_address
}

output "frontend_private_ip" {
  value = oci_core_instance.frontend_instance.private_ip
}

output "backend_private_ip" {
  value = oci_core_instance.backend_instance.private_ip
}

output "db_private_ip" {
  value = oci_core_instance.db_instance.private_ip
}

output "jump_host_private_ip" {
  value = oci_core_instance.jump_host.private_ip
}

output "bastion_id" {
  value = oci_bastion_bastion.wis_bastion.id
}


# Bastion SSH command (to create bastion session )
output "bastion_session_command" {
  value = <<-EOT
    # Create Bastion session for jump host
    PUB_KEY=$(cat ${var.ssh_public_key_path})
    
    oci bastion session create \\
      --bastion-id ${oci_bastion_bastion.wis_bastion.id} \\
      --session-ttl-in-seconds 1800 \\
      --target-resource-details '{
        "sessionType": "PORT_FORWARDING",
        "targetResourceId": "${oci_core_instance.jump_host.id}",
        "targetResourcePort": 22,
        "targetResourceOperatingSystemUserName": "opc",
        "sshPublicKey": "'"$PUB_KEY"'"
      }'

    
    # oci bastion session get --session-id <SESSION_ID> --query "data.ssh-metadata.command"
  EOT
  description = "Command to create Bastion session for jump host"
}

# SSH from Jump Host to Frontend
output "ssh_to_frontend_from_jump" {
  value = "ssh -i ${var.private_key} opc@${oci_core_instance.frontend_instance.private_ip}"
  description = "Command to SSH from Jump Host to Frontend instance"
  sensitive = true
}

# SSH from Jump Host to Backend
output "ssh_to_backend_from_jump" {
  value = "ssh -i ${var.private_key} opc@${oci_core_instance.backend_instance.private_ip}"
  description = "Command to SSH from Jump Host to Backend instance"
  sensitive = true
}

# SSH from Jump Host to Database
output "ssh_to_db_from_jump" {
  value = "ssh -i ${var.private_key} opc@${oci_core_instance.db_instance.private_ip}"
  description = "Command to SSH from Jump Host to Database instance"
  sensitive = true
}
