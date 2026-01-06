
# Compartment for the project
resource "oci_identity_compartment" "wis_compartment" {
  compartment_id = var.tenancy_ocid
  name        = "WIS_3Tier_App"
  description = "Compartment for 3-tier application project"
  enable_delete = true
}


# for Remote Terraform State

resource "oci_objectstorage_bucket" "terraform_state" {
  compartment_id = oci_identity_compartment.wis_compartment.id
  namespace      = "axqaai9um4hk"
  name           = "wis-terraform-state"
  access_type    = "NoPublicAccess"
  versioning     = "Enabled"
  
  depends_on = [oci_identity_compartment.wis_compartment]
}


# Data Sources to get the availability domains,free images and other data

data "oci_identity_availability_domains" "ads" {
  compartment_id = oci_identity_compartment.wis_compartment.id
  depends_on     = [oci_identity_compartment.wis_compartment]
}

data "oci_core_images" "oracle_linux" {
  compartment_id           = oci_identity_compartment.wis_compartment.id
  operating_system         = "Oracle Linux"
  operating_system_version = "8"
  shape                    = "VM.Standard.E4.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
  
  depends_on = [oci_identity_compartment.wis_compartment]
}
data "oci_core_images" "arm_oracle_linux" {
  compartment_id           = var.tenancy_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = "8"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
  depends_on = [oci_identity_compartment.wis_compartment]
  filter {
    name   = "display_name"
    values = [".*aarch64.*"]
    regex  = true
  }
}
data "oci_core_images" "V2_oracle_linux" {
  compartment_id           = oci_identity_compartment.wis_compartment.id
  operating_system         = "Oracle Linux"
  operating_system_version = "8"
  shape                    = "VM.Standard.E2.1.Micro"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
  
  depends_on = [oci_identity_compartment.wis_compartment]
}