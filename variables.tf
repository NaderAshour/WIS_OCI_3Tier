
# OCI Authentication
variable "tenancy_ocid" {
  description = "OCI Tenancy OCID"
  type        = string
}

variable "user_ocid" {
  description = "OCI User OCID"
  type        = string
}

variable "fingerprint" {
  description = "API Key Fingerprint"
  type        = string
}

variable "private_key" {
  description = "Path to OCI API private key"
  type        = string
  default     = ""
  sensitive   = true
}


variable "region" {
  description = "OCI region"
  type        = string
  default     = "me-jeddah-1"
}
variable "compartment_ocid" {
  description = "OCID of the compartment"
  type        = string
  default     = ""
}

# Compute

variable "compute_shape" {
  description = "Compute shape"
  type        = string
  default     = "VM.Standard.E2.1.Micro"
}

variable "ocpus" {
  default = "1"
}

variable "memory_in_gbs" {
  default = "1"
}
# KEYS
variable "ssh_public_key_path" {
  description = "Path to SSH public key"
  type        = string
}

