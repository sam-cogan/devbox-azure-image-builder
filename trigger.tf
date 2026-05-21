# Opt-in build trigger.
#
# `terraform apply` does NOT kick off an image build by default. Set
# -var=trigger_build_on_apply=true (and typically also
# -replace=time_static.image_version to bump the version stamp) to force
# the template to be recreated and this action to re-execute against the
# new template.
#
# azapi_resource_action is used because the run action is a POST .../run
# with no body and azurerm has no equivalent.

resource "azapi_resource_action" "build" {
  count = var.trigger_build_on_apply ? 1 : 0

  type        = "Microsoft.VirtualMachineImages/imageTemplates@2024-02-01"
  resource_id = azapi_resource.image_template.id
  action      = "run"
  method      = "POST"

  # Re-run the action whenever the underlying template is replaced or the
  # version stamp is rotated.
  lifecycle {
    replace_triggered_by = [
      azapi_resource.image_template,
      time_static.image_version,
    ]
  }
}
