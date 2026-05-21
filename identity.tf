# User-assigned managed identity that AIB will assume while it builds the
# image, plus the minimum custom RBAC role described at
# https://learn.microsoft.com/azure/virtual-machines/linux/image-builder-permissions-cli
#
# The role is scoped to the imaging resource group only. AIB uses its own
# managed network for the build VM, so no subnet-join permissions are needed.

resource "azurerm_user_assigned_identity" "aib" {
  name                = var.identity_name
  resource_group_name = azurerm_resource_group.imaging.name
  location            = azurerm_resource_group.imaging.location
  tags                = var.tags
}

# Custom role definition mirroring the documented "Azure Image Builder Service
# Image Creation Role". Re-creating it as a custom role (rather than relying on
# the built-in Contributor) keeps the blast radius small.
resource "azurerm_role_definition" "aib" {
  name        = var.custom_role_name
  scope       = azurerm_resource_group.imaging.id
  description = "Minimum permissions for Azure Image Builder to build images and publish versions into the imaging RG."

  permissions {
    actions = [
      "Microsoft.Compute/galleries/read",
      "Microsoft.Compute/galleries/images/read",
      "Microsoft.Compute/galleries/images/versions/read",
      "Microsoft.Compute/galleries/images/versions/write",

      "Microsoft.Compute/images/write",
      "Microsoft.Compute/images/read",
      "Microsoft.Compute/images/delete",

      "Microsoft.Storage/storageAccounts/blobServices/containers/read",
      "Microsoft.Storage/storageAccounts/blobServices/containers/write",
      "Microsoft.Storage/storageAccounts/blobServices/read",

      "Microsoft.ContainerInstance/containerGroups/read",
      "Microsoft.ContainerInstance/containerGroups/write",
      "Microsoft.ContainerInstance/containerGroups/start/action",

      "Microsoft.Authorization/*/read",
      "Microsoft.Resources/deployments/*",
      "Microsoft.Resources/deploymentScripts/read",
      "Microsoft.Resources/deploymentScripts/write",

      "Microsoft.VirtualMachineImages/imageTemplates/run/action",
    ]
    not_actions = []
  }

  assignable_scopes = [
    azurerm_resource_group.imaging.id,
  ]
}

resource "azurerm_role_assignment" "aib_rg" {
  scope              = azurerm_resource_group.imaging.id
  role_definition_id = azurerm_role_definition.aib.role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.aib.principal_id

  # The role definition is eventually consistent; without skip_service_principal_aad_check
  # the assignment can race against AAD propagation of the MI's principal.
  skip_service_principal_aad_check = true
}
