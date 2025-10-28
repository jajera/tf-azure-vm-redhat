locals {
  common_tags = {
    Environment = "demo"
    ManagedBy   = "terraform"
    Project     = "redhat-vm-demo"
    Region      = var.location
  }
}
