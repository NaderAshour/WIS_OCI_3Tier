# OCI 3-Tier Application Infrastructure

This Terraform project provisions a secure 3-tier application infrastructure on Oracle Cloud Infrastructure (OCI) with remote state management.

## Architecture Overview

- **Frontend Tier**: Web servers in private subnet
- **Backend Tier**: Application servers in private subnet  
- **Database Tier**: Database servers in private subnet
- **Load Balancer**: Public-facing load balancer
- **Bastion Service**: Secure access to private instances
- **Jump Host**: SSH gateway for administrative access

## Prerequisites

Before you begin, ensure you have:

1. **OCI Account** with appropriate permissions
2. **OCI CLI** installed and configured
3. **Terraform** (>= 1.5.0) installed
4. **SSH Key Pair** generated
5. **Git** installed

---

## Initial Setup

### Step 1: Install Required Tools

#### Install OCI CLI

**Linux/macOS:**
```bash
bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)"
```

**Windows (PowerShell):**
```powershell
Set-ExecutionPolicy RemoteSigned
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.ps1'))"
```

#### Install Terraform

**Linux:**
```bash
wget https://releases.hashicorp.com/terraform/1.7.0/terraform_1.7.0_linux_amd64.zip
unzip terraform_1.7.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

**macOS:**
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

**Windows:**
Download from https://www.terraform.io/downloads and add to PATH

---

### Step 2: Configure OCI Authentication

#### 2.1 Generate OCI API Key

1. Login to OCI Console: https://cloud.oracle.com
2. Click **Profile Icon** → **User Settings**
3. Under **API Keys**, click **Add API Key**
4. Select **Generate API Key Pair**
5. Click **Download Private Key** (save as `oci_api_key.pem`)
6. Click **Add**
7. **Copy the configuration preview** (you'll need this)

#### 2.2 Setup OCI Config File

Create `~/.oci/config`:
or cli will create it by runing OCI config and fill required fields

**Linux/macOS:**
```bash
mkdir -p ~/.oci
nano ~/.oci/config
```

**Windows:**
```powershell
mkdir $HOME\.oci
notepad $HOME\.oci\config
```

Paste the configuration from OCI Console:
```ini
[DEFAULT]
user=ocid1.user.oc1..aaaaaaaXXXXXXXXXXXX
fingerprint=aa:bb:cc:dd:ee:ff:gg:hh:ii:jj:kk:ll:mm:nn:oo:pp
tenancy=ocid1.tenancy.oc1..aaaaaaaXXXXXXXXXXX
region=me-jeddah-1
key_file=~/.oci/oci_api_key.pem
```

#### 2.3 Move the Private Key

**Linux/macOS:**
```bash
mv ~/Downloads/oracleidentitycloudservice_*.pem ~/.oci/oci_api_key.pem
chmod 600 ~/.oci/oci_api_key.pem
chmod 600 ~/.oci/config
```

**Windows:**
```powershell
Move-Item $HOME\Downloads\oracleidentitycloudservice_*.pem $HOME\.oci\oci_api_key.pem
```

#### 2.4 Test OCI CLI

```bash
oci iam region list
```

You should see a list of OCI regions. If you get an authentication error, verify your config file.

---

### Step 3: Generate SSH Keys for Instance Access

These keys are different from the OCI API keys and are used to SSH into compute instances.

**Linux/macOS:**
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
```

**Windows:**
```powershell
ssh-keygen -t rsa -b 4096 -f $HOME\.ssh\id_rsa
```

Press Enter when prompted for a passphrase (or set one for extra security).

---

### Step 4: Clone the Repository

```bash
git clone https://github.com/YOUR_USERNAME/oci-3tier-infra.git
cd oci-3tier-infra
```

---

### Step 5: Configure Terraform Variables

#### 5.1 Copy the Example Variables File

```bash
cp terraform.tfvars.example terraform.tfvars
```

#### 5.2 Edit `terraform.tfvars`

Open `terraform.tfvars` and fill in your values:

```terraform
# OCI Authentication
tenancy_ocid = "ocid1.tenancy.oc1..aaaaaaaXXXXXXXXXXX"  # From ~/.oci/config
user_ocid    = "ocid1.user.oc1..aaaaaaaXXXXXXXXXXX"     # From ~/.oci/config
fingerprint  = "aa:bb:cc:dd:ee:ff:gg:hh:ii:jj:kk:ll:mm:nn:oo:pp"  # From ~/.oci/config
region       = "me-jeddah-1"  # Your preferred region

# SSH Keys (use forward slashes even on Windows)
ssh_public_key_path = "~/.ssh/id_rsa.pub"  # Or full path: /home/user/.ssh/id_rsa.pub

# Leave empty for bootstrap (will be filled after Stage 1)
compartment_ocid = ""
```

**Important:** 
- Use **forward slashes** `/` in paths, even on Windows
- Don't commit `terraform.tfvars` to Git (it's in `.gitignore`)

---

## Deployment Process

This deployment uses a **two-stage approach** to handle the chicken-and-egg problem of storing Terraform state in OCI before the infrastructure exists.

### **STAGE 1: Bootstrap (Create Compartment & State Bucket)**

#### Step 1.1: Comment Out Backend Configuration

Edit `provider.tf` and ensure the backend block is **commented out**:

```terraform
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0.0"
    }
  }

  # COMMENT THIS OUT FOR STAGE 1
  # backend "oci" {
  #   bucket    = "wis-terraform-state"
  #   namespace = "YOUR_NAMESPACE"
  #   region    = "me-jeddah-1"
  #   key       = "WIS_3Tier_App/terraform.tfstate"
  # }
}

provider "oci" {
  config_file_profile = "DEFAULT"
}
```

#### Step 1.2: Initialize Terraform

```bash
terraform init
```

#### Step 1.3: Create Compartment and State Bucket Only

Use targeted apply to create only the foundational resources:
U can also change the name of the files from (main.tf to main.tfanythinghere) except the bootstrp_state file until u apply it .

```bash
terraform apply \
  -target=oci_identity_compartment.wis_compartment \
  -target=oci_objectstorage_bucket.terraform_state \
  -target=data.oci_identity_availability_domains.ads \
  -target=data.oci_core_images.oracle_linux
```

Type `yes` when prompted.

**Expected Output:**
```
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
```

#### Step 1.4: Save the Compartment OCID

```bash
terraform state show oci_identity_compartment.wis_compartment | grep "^id"
```

Copy the OCID (looks like `ocid1.compartment.oc1..aaaaaaaXXXXXXXXXX`)

#### Step 1.5: Get Your Object Storage Namespace

```bash
oci os ns get
```

Save this namespace value.

---

### **STAGE 2: Migrate to Remote State**

#### Step 2.1: Update `terraform.tfvars`

Add the compartment OCID you saved:

```terraform
compartment_ocid = "ocid1.compartment.oc1..aaaaaaaXXXXXXXXXX"
```

#### Step 2.2: Update `provider.tf`

Uncomment the backend block and add your values:

```terraform
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0.0"
    }
  }

  # UNCOMMENT THIS FOR STAGE 2
  backend "oci" {
    bucket    = "wis-terraform-state"
    namespace = "YOUR_NAMESPACE_HERE"  # From 'oci os ns get'
    region    = "me-jeddah-1"
    key       = "WIS_3Tier_App/terraform.tfstate"
  }
}

provider "oci" {
  config_file_profile = "DEFAULT"
}
```

#### Step 2.3: Migrate State to Remote Backend

```bash
terraform init -migrate-state
```

When prompted:
```
Do you want to copy existing state to the new backend?
  Enter a value: yes
```

Type `yes` and press Enter.

#### Step 2.4: Verify Remote State

```bash
terraform state list
```

Should show your existing resources.

#### Step 2.5: Clean Up Local State Files

```bash
rm terraform.tfstate terraform.tfstate.backup
```

**✅ Your state is now safely stored in OCI Object Storage!**

---

### **STAGE 3: Deploy Full Infrastructure**

#### Step 3.1: Review the Plan

```bash
terraform plan
```

This will show all remaining resources to be created:
- VCN and Subnets
- Internet Gateway and NAT Gateway
- Route Tables
- Network Security Groups
- 4 Compute Instances (Jump Host, Frontend, Backend, Database)
- Load Balancer
- Bastion Service

#### Step 3.2: Apply Full Configuration

```bash
terraform apply
```

Type `yes` when prompted.

**This will take 5-10 minutes.** ☕

#### Step 3.3: Save Outputs

```bash
terraform output > infrastructure_details.txt
```

---

## Accessing Your Infrastructure

### View Connection Information

```bash
# View all outputs
terraform output

# View specific output
terraform output load_balancer_public_ip
```

### Connect to Private Instances

#### Option 1: Via Bastion Service (Recommended)

**Step 1:** Create a bastion session:
```bash
oci bastion session create \
  --bastion-id $(terraform output -raw bastion_id) \
  --display-name "admin-session" \
  --session-ttl-in-seconds 10800 \
  --target-resource-details '{
    "sessionType": "MANAGED_SSH", or "PORT_FORWARDING" if u didn't add management agent while provision this instance 
    "targetResourceOperatingSystemUserName": "opc",
    "targetResourceId": "INSTANCE_OCID",
    "targetResourcePort": 22
  }' \
  --ssh-public-key-file ~/.ssh/id_rsa.pub
```

**Step 2:** Connect via bastion:
```bash
ssh -i ~/.ssh/id_rsa <SESSION_OCID>@host.bastion.<region>.oci.oraclecloud.com
```

#### Option 2: Via Jump Host

Get the jump host IP:
```bash
terraform output jump_host_private_ip
```

From jump host, access other instances:
```bash
ssh opc@<FRONTEND_IP>
ssh opc@<BACKEND_IP>
ssh opc@<DB_IP>
```


## Project Structure

```
.
├── README.md                  # This file
├── .gitignore                 # Git ignore rules
├── terraform.tfvars.example   # Example variables (commit this)
├── terraform.tfvars           # Your actual values (DON'T commit)
├── provider.tf                # Provider and backend config
├── variables.tf               # Variable declarations
├── bootstrap_state.tf         # Compartment and state bucket
├── networking.tf              # VCN, subnets, gateways, route tables
├── security_groups.tf         # Network Security Groups
├── main.tf                    # Compute instances, load balancer, bastion
├── outputs.tf                 # Output values
└── helper_commands            # Useful CLI commands
```

---

## Important Files Explanation

### `terraform.tfvars.example`
Template showing what variables need to be set. **Commit this to Git.**

### `terraform.tfvars`
Your actual values with sensitive information. **Never commit this!**

### `bootstrap_state.tf`
Creates the compartment and OCI bucket used for remote state storage.

### `provider.tf`
Configures Terraform to use OCI provider and remote state backend.

---

## Maintenance Commands

### Update Infrastructure

```bash
# Make changes to .tf files
terraform plan    # Review changes
terraform apply   # Apply changes
```

### View Current State

```bash
terraform show
terraform state list
```

### Refresh Outputs

```bash
terraform refresh
terraform output
```

### Destroy Infrastructure

**⚠️ WARNING: This will delete everything!**

```bash
terraform destroy
```

---

## Troubleshooting

### Authentication Errors

**Error:** `401-NotAuthenticated`

**Solution:** Verify your OCI config:
```bash
cat ~/.oci/config
oci iam region list
```

Regenerate API key if needed (see Step 2 above).

### Permission Errors

**Error:** `NotAuthorizedOrNotFound`

**Solution:** Ensure your user has the required IAM policies:
- `manage compartments`
- `manage vcns`
- `manage compute-management`
- `manage load-balancers`
- `manage bastion-family`

### Backend Initialization Failed

**Error:** `Backend configuration changed`

**Solution:**
```bash
terraform init -reconfigure
```

### SSH Connection Issues

**Error:** `Permission denied (publickey)`

**Solution:** Verify your SSH keys match:
```bash
# Check local public key
cat ~/.ssh/id_rsa.pub

# Compare with what's on the instance (via OCI Console)
# They must match exactly
```

### State Lock Errors

**Error:** `Error acquiring the state lock`

**Solution:**
```bash
terraform force-unlock <LOCK_ID>
```

---

## Security Best Practices

### ✅ DO:
- Use separate SSH keys for different environments
- Restrict bastion access to your IP only
- Enable MFA on your OCI account
- Regularly rotate API keys
- Use NSGs instead of security lists
- Keep Terraform and OCI CLI updated
- Review `terraform plan` before applying

### ❌ DON'T:
- Commit `terraform.tfvars` or state files to Git
- Share SSH private keys
- Allow SSH from `0.0.0.0/0` to instances
- Use default security settings
- Run Terraform with elevated privileges unnecessarily

---
