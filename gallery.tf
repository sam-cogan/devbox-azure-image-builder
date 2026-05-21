# Azure Compute Gallery + the Windows 11 image definition that AIB will publish
# versions into. The image definition's metadata is what Dev Box reads when it
# validates whether an image is usable.

resource "azurerm_shared_image_gallery" "this" {
  name                = var.gallery_name
  resource_group_name = azurerm_resource_group.imaging.name
  location            = azurerm_resource_group.imaging.location
  description         = "Custom Dev Box base images with WSL / VirtualMachinePlatform / Windows Sandbox pre-enabled."
  tags                = var.tags
}

resource "azurerm_shared_image" "win11_wsl" {
  name                = var.image_definition_name
  gallery_name        = azurerm_shared_image_gallery.this.name
  resource_group_name = azurerm_resource_group.imaging.name
  location            = azurerm_resource_group.imaging.location

  os_type = "Windows"

  # Dev Box hard requirements (see
  # https://learn.microsoft.com/azure/dev-box/how-to-troubleshoot-custom-image-validation):
  #   * Hyper-V generation must be V2.
  #   * Image must be generalized (not specialized).
  #   * Trusted Launch security type is required; images without Trusted Launch
  #     metadata fail Dev Box validation even if they otherwise work.
  hyper_v_generation     = "V2"
  specialized            = false # generalized image (Dev Box rejects specialized)
  trusted_launch_enabled = true

  identifier {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
  }

  tags = var.tags
}
