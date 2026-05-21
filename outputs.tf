output "resource_group_name" {
  description = "Imaging resource group name."
  value       = azurerm_resource_group.imaging.name
}

output "gallery_id" {
  description = "Resource ID of the Azure Compute Gallery."
  value       = azurerm_shared_image_gallery.this.id
}

output "gallery_name" {
  description = "Name of the Azure Compute Gallery."
  value       = azurerm_shared_image_gallery.this.name
}

output "image_definition_id" {
  description = "Resource ID of the shared image definition."
  value       = azurerm_shared_image.win11_wsl.id
}

output "image_definition_name" {
  description = "Name of the shared image definition."
  value       = azurerm_shared_image.win11_wsl.name
}

output "aib_identity_principal_id" {
  description = "Principal (object) ID of the AIB user-assigned managed identity."
  value       = azurerm_user_assigned_identity.aib.principal_id
}

output "aib_identity_resource_id" {
  description = "Resource ID of the AIB user-assigned managed identity."
  value       = azurerm_user_assigned_identity.aib.id
}

output "image_template_id" {
  description = "Resource ID of the AIB image template."
  value       = azapi_resource.image_template.id
}

output "current_image_version" {
  description = "Version stamp that will be produced on the next build (1.0.<unix>)."
  value       = local.image_version
}

# Drop-in reference for Dev Box imagedefinition.yaml:
#   image: <gallery>/<imageDefinition>@latest
output "devbox_image_reference" {
  description = "Reference string to paste into Dev Box imagedefinition.yaml as `image: <value>@latest`."
  value       = "${azurerm_shared_image_gallery.this.name}/${azurerm_shared_image.win11_wsl.name}"
}
