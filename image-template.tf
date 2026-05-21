# Azure Image Builder image template.
#
# Modelled as azapi_resource because azurerm has no stable resource for
# Microsoft.VirtualMachineImages/imageTemplates.
#
# Key design notes:
#   * The customize block enables WSL / VirtualMachinePlatform / Windows
#     Sandbox features with -NoRestart, then runs an explicit WindowsRestart.
#     The reboot is what commits the CBS pending transaction. Without it
#     sysprep fails with "Sysprep_Clean_Validate_Opk: There are one or more
#     Windows updates that require a reboot".
#   * A second WindowsRestart follows Windows Update for the same reason.
#   * Networking uses AIB's default managed network (no vnetConfig). The
#     build VM does not need to reach any internal resources.
#   * The image version is stamped into galleryImageId as 1.0.<unix> so
#     every intentional rebuild produces a fresh gallery image version.
#   * Image templates are practically immutable, so replace_triggered_by
#     on time_static.image_version forces a fresh template + build when
#     the timestamp is rotated.

locals {
  image_definition_id = azurerm_shared_image.win11_wsl.id

  gallery_image_version_id = "${local.image_definition_id}/versions/${local.image_version}"
}

resource "azapi_resource" "image_template" {
  type      = "Microsoft.VirtualMachineImages/imageTemplates@2024-02-01"
  name      = "it-${var.image_definition_name}"
  parent_id = azurerm_resource_group.imaging.id
  location  = azurerm_resource_group.imaging.location
  tags      = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aib.id]
  }

  body = {
    properties = {
      buildTimeoutInMinutes = var.build_timeout_minutes

      # Tags applied to every resource AIB creates in the IT_* staging RG.
      # SecurityControl=Ignore is used to exempt the auto-created staging
      # storage account from any tenant policy that forces
      # allowSharedKeyAccess=false on new storage accounts. Without this
      # tag the build can fail at VHD capture with KeyBasedAuthenticationNotPermitted.
      managedResourceTags = {
        SecurityControl = "Ignore"
        managed-by      = "azure-image-builder"
        workload        = "devbox-custom-image"
      }

      vmProfile = {
        vmSize       = var.build_vm_size
        osDiskSizeGB = var.build_vm_os_disk_size_gb
      }

      source = {
        type      = "PlatformImage"
        publisher = var.base_image_publisher
        offer     = var.base_image_offer
        sku       = var.base_image_sku
        version   = var.base_image_version
      }

      customize = [
        # 1. Enable WSL. -NoRestart is mandatory: AIB does not allow a
        #    customize step to reboot the VM on its own; we use the explicit
        #    WindowsRestart step below to commit pending transactions.
        {
          type        = "PowerShell"
          name        = "EnableWSL"
          runElevated = true
          runAsSystem = true
          inline = [
            "Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -All -NoRestart"
          ]
        },

        # 2. Enable Virtual Machine Platform (required for WSL2 and Sandbox).
        {
          type        = "PowerShell"
          name        = "EnableVirtualMachinePlatform"
          runElevated = true
          runAsSystem = true
          inline = [
            "Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -All -NoRestart"
          ]
        },

        # 3. Enable Windows Sandbox (Containers-DisposableClientVM).
        {
          type        = "PowerShell"
          name        = "EnableWindowsSandbox"
          runElevated = true
          runAsSystem = true
          inline = [
            "Enable-WindowsOptionalFeature -Online -FeatureName Containers-DisposableClientVM -All -NoRestart"
          ]
        },

        # 4. CRITICAL: reboot to commit the CBS pending transaction. Sysprep
        #    will fail at capture time if this is missing.
        {
          type           = "WindowsRestart"
          name           = "RestartAfterFeatures"
          restartTimeout = "10m"
        },

        # 5. Apply latest security + critical updates. Preview / optional
        #    updates are excluded so monthly rebuilds remain predictable.
        {
          type           = "WindowsUpdate"
          name           = "InstallCumulativeUpdates"
          searchCriteria = "IsInstalled=0"
          filters = [
            "exclude:$_.Title -like '*Preview*'",
            "include:$true",
          ]
          updateLimit = 40
        },

        # 6. Second reboot so the WU CBS transaction is also committed
        #    before AIB hands off to sysprep.
        {
          type           = "WindowsRestart"
          name           = "RestartAfterUpdates"
          restartTimeout = "30m"
        },
      ]

      distribute = [
        {
          type               = "SharedImage"
          galleryImageId     = local.gallery_image_version_id
          runOutputName      = "${var.image_definition_name}-out"
          replicationRegions = var.replication_regions
          storageAccountType = "Standard_LRS"
          artifactTags = {
            source-publisher = var.base_image_publisher
            source-offer     = var.base_image_offer
            source-sku       = var.base_image_sku
            built-by         = "azure-image-builder"
            version          = local.image_version
          }
        }
      ]
    }
  }

  # AIB image templates are effectively immutable: most property changes are
  # rejected with a 400. Force a clean replace whenever the version stamp
  # changes so the next apply provisions a new template and the trigger then
  # publishes the next gallery image version.
  lifecycle {
    replace_triggered_by = [
      time_static.image_version,
    ]
  }

  depends_on = [
    # The role assignment must be in place before the template tries to
    # validate, otherwise template creation fails with "principal does not
    # have permission on the gallery".
    azurerm_role_assignment.aib_rg,
  ]

  # Image build itself runs separately via azapi_resource_action in trigger.tf.
  # Creating the template is fast (just validation); the long-running build
  # is decoupled so plain plans/applies stay snappy.
  timeouts {
    create = "30m"
    delete = "30m"
  }
}
