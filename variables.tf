############################################
# Core / location
############################################

variable "location" {
  description = "Azure region for the imaging resource group and gallery."
  type        = string
  default     = "swedencentral"
}

variable "resource_group_name" {
  description = "Resource group that holds the gallery, identity, and AIB template. Keep this separate from any Dev Box resource group."
  type        = string
  default     = "rg-devbox-imaging"
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default = {
    workload   = "devbox-custom-image"
    managed-by = "terraform"
    repo       = "devbox-aib"
  }
}

############################################
# Gallery / image definition
############################################

variable "gallery_name" {
  description = "Name of the Azure Compute Gallery. Compute Gallery names must be alphanumeric, periods, or underscores (no hyphens)."
  type        = string
  default     = "gal_devbox_images"
}

variable "image_definition_name" {
  description = "Name of the shared image definition inside the gallery. This is what you reference from imagedefinition.yaml."
  type        = string
  default     = "win11-wsl-enabled"
}

variable "image_publisher" {
  description = "Publisher metadata stamped on the image definition (purely informational, you choose it)."
  type        = string
  default     = "Contoso"
}

variable "image_offer" {
  description = "Offer metadata stamped on the image definition."
  type        = string
  default     = "DevBoxWin11"
}

variable "image_sku" {
  description = "SKU metadata stamped on the image definition."
  type        = string
  default     = "WSL-Enabled"
}

############################################
# Base (source) marketplace image
############################################
# Default: the Microsoft-published Visual Studio 2022 Enterprise + M365 + Win11
# Gen2 image, which is the recommended Dev Box starting point because it already
# ships with VS, Office, and the Dev Box agent prerequisites.

variable "base_image_publisher" {
  description = "Marketplace publisher of the base image used as AIB source."
  type        = string
  default     = "microsoftvisualstudio"
}

variable "base_image_offer" {
  description = "Marketplace offer of the base image."
  type        = string
  default     = "visualstudioplustools"
}

variable "base_image_sku" {
  description = "Marketplace SKU of the base image. Must be a Gen2 SKU because Dev Box requires hyper_v_generation V2."
  type        = string
  default     = "vs-2022-ent-general-win11-m365-gen2"
}

variable "base_image_version" {
  description = "Marketplace image version. 'latest' is recommended so monthly rebuilds pick up the newest publisher release."
  type        = string
  default     = "latest"
}

############################################
# Identity
############################################

variable "identity_name" {
  description = "Name of the user-assigned managed identity that AIB uses to build and publish images."
  type        = string
  default     = "id-devbox-aib"
}

variable "custom_role_name" {
  description = "Name of the custom RBAC role granting AIB the minimum permissions on the imaging RG."
  type        = string
  default     = "Azure Image Builder Service Image Creation Role (devbox-aib)"
}

############################################
# Build VM
############################################

variable "build_vm_size" {
  description = "Size of the transient VM AIB spins up to run customisations. D4s_v5 is a good balance for Windows + WSL feature install + WU."
  type        = string
  default     = "Standard_D4s_v5"
}

variable "build_vm_os_disk_size_gb" {
  description = "OS disk size in GB for the build VM. 128 gives plenty of headroom for Windows Update."
  type        = number
  default     = 128
}

variable "build_timeout_minutes" {
  description = "AIB hard timeout for the entire build (source + customise + distribute). 240 minutes is generous for Windows + WU."
  type        = number
  default     = 240
}

############################################
# Distribution / replication
############################################

variable "replication_regions" {
  description = "List of regions the image is replicated to. Defaults to just the primary location."
  type        = list(string)
  default     = ["swedencentral"]
}

############################################
# Build trigger
############################################

variable "trigger_build_on_apply" {
  description = "If true, `terraform apply` will POST .../run to the image template and kick off a build. Default false so plain applies are idempotent and only the CI workflow triggers builds."
  type        = bool
  default     = false
}
