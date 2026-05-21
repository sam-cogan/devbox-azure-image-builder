# Providers and the imaging resource group.

provider "azurerm" {
  # Resource provider registration check is left to the operator; the README
  # lists the providers that must be registered (Microsoft.VirtualMachineImages,
  # Microsoft.Compute, Microsoft.KeyVault, Microsoft.Storage, Microsoft.Network,
  # Microsoft.ContainerInstance).
  features {}
}

provider "azapi" {}

data "azurerm_subscription" "current" {}

data "azurerm_client_config" "current" {}

# Stable timestamp used to derive the image version (1.0.<unix>). To produce a
# new version, run:
#   terraform apply -replace=time_static.image_version
resource "time_static" "image_version" {}

locals {
  image_version = "1.0.${time_static.image_version.unix}"
}

resource "azurerm_resource_group" "imaging" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}
