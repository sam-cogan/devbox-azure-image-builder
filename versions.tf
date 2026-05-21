terraform {
  required_version = ">= 1.6.0"

  required_providers {
    # azurerm covers everything with first-class support (RG, gallery, image
    # definition, managed identity, role assignment, networking, peering).
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.14"
    }

    # azapi is used ONLY for the Azure Image Builder image template, because
    # there is no stable azurerm resource for
    # Microsoft.VirtualMachineImages/imageTemplates as of azurerm 4.x.
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.2"
    }

    # time_static is used to stamp the image version (1.0.<unix>) so each
    # intentional rebuild produces a fresh gallery image version. Bump it
    # with `terraform apply -replace=time_static.image_version`.
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
