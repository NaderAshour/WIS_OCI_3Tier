terraform {
  required_version = ">= 1.5.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0.0"
    }
  } 
  # this backend to be commented before first apply because the bucket and the compartment dosent exist yet 
  # after commenting the back and go and apply the bootstrap_state.tf to create the bucket and the compartment 
  # then un comment the backend and run the terraform migrate-state to migrate the localstate to the remote backend
    backend "oci" {
      bucket           = "wis-terraform-state"
      namespace        = "axqaai9um4hk"
      region           = "me-jeddah-1"
      key              = "WIS_3Tier_App/terraform.tfstate"
  }
}

provider "oci" {
   # i can replace them with config=DEFAULT but this is better for flexibility
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key      = file(var.private_key)
  region           = var.region
}

