# Azure RedHat VM Demo

Terraform configuration to provision a RedHat Enterprise Linux VM in Azure.

## Prerequisites

- Terraform >= 1.0
- Azure CLI configured
- Azure subscription

## Resources Created

- Resource Group
- Virtual Network and Subnets
- Network Security Group
- Azure Bastion (optional, enabled by default)
- NAT Gateway
- RedHat VM (latest 9.x via data source)
- Auto-generated 16-character password

## Usage

```bash
# Login to Azure
az login

# Initialize
terraform init

# Deploy
terraform apply

# Get password
terraform output vm_admin_password
```

### Connect via Azure Portal

1. Go to [Azure Portal](https://portal.azure.com)
2. Open VM: `tf-vm-redhat-demo`
3. Click Connect → Bastion
4. Username: `azureuser`, password from outputs above

## Configuration

Edit `terraform.tfvars` to customize:

- `subscription_id`: Azure subscription ID
- `location`: Region (default: `australiaeast`)
- `vm_size`: VM size (default: `Standard_B2s`)

Disable Bastion: Set `enable_bastion = false` in `terraform.tfvars`

## Cleanup

```bash
terraform destroy
```

## Outputs

- `vm_admin_password` - Auto-generated password
- `vm_connection_info` - VM details (name, IP, region, etc.)
- `bastion_connection_info` - Bastion connection details
