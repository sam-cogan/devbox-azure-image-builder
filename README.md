# devbox-aib

Terraform-based [Azure Image Builder][aib] pipeline that produces a custom
Windows 11 base image for [Microsoft Dev Box][devbox], with the following
optional features **pre-enabled and baked into the image**:

- `Microsoft-Windows-Subsystem-Linux` (WSL)
- `VirtualMachinePlatform`
- `Containers-DisposableClientVM` (Windows Sandbox)

The image is published to an Azure Compute Gallery and can be referenced from
a Dev Box `imagedefinition.yaml` as:

```yaml
image: <galleryName>/<imageDefinitionName>@latest
```

## What gets created

| Resource | Purpose |
| --- | --- |
| `azurerm_resource_group.imaging` | Holds everything below. |
| `azurerm_shared_image_gallery.this` | Compute Gallery the image is published to. |
| `azurerm_shared_image.win11_wsl` | Image definition: Windows, Gen2, generalized, Trusted Launch (all Dev Box requirements). |
| `azurerm_user_assigned_identity.aib` | Managed identity AIB runs under. |
| `azurerm_role_definition.aib` + `azurerm_role_assignment.aib_rg` | Custom RBAC role scoped to the imaging RG. |
| `azapi_resource.image_template` | AIB image template (PlatformImage → enable features → restart → WU → restart → SharedImage). |
| `azapi_resource_action.build` | Opt-in `POST .../run` to trigger a build. |

## Prereqs

1. **Azure subscription** with the following resource providers registered:
   - `Microsoft.VirtualMachineImages`
   - `Microsoft.Compute`
   - `Microsoft.KeyVault`
   - `Microsoft.Storage`
   - `Microsoft.Network`
   - `Microsoft.ContainerInstance`

   ```sh
   for p in Microsoft.VirtualMachineImages Microsoft.Compute Microsoft.KeyVault Microsoft.Storage Microsoft.Network Microsoft.ContainerInstance; do
     az provider register -n $p
   done
   ```

2. **Tooling**:
   - Terraform >= 1.6
   - `azurerm` provider >= 4.x (pinned via `versions.tf`)
   - `azapi` provider >= 2.x (pinned via `versions.tf`)

3. **Executing principal** (the SP / user running Terraform) needs:
   - `Owner` (or `Contributor` + `User Access Administrator`) on the
     subscription, scoped at least to where the imaging RG will be created.
     The `User Access Administrator` portion is required because Terraform
     creates a custom role definition and assigns it.

4. **Marketplace terms**: the default base image
   (`microsoftvisualstudio / visualstudioplustools / vs-2022-ent-general-win11-m365-gen2`)
   may require accepting marketplace terms in your subscription first:

   ```sh
   az vm image terms accept \
     --publisher microsoftvisualstudio \
     --offer visualstudioplustools \
     --plan vs-2022-ent-general-win11-m365-gen2
   ```

## One-time setup

```sh
terraform init
terraform apply
```

By default this will:
- Provision the RG, gallery, image definition, identity, role assignment,
  and the AIB image template.
- **Not** run a build. `trigger_build_on_apply` defaults to `false`, so
  applies are idempotent.

To produce the first image version, kick off a build:

```sh
terraform apply -var=trigger_build_on_apply=true
```

…or trigger the GitHub Action manually (`workflow_dispatch`).

The build runs asynchronously inside AIB. Track it with:

```sh
az image builder show \
  --resource-group rg-devbox-imaging \
  --name it-win11-wsl-enabled \
  --query "lastRunStatus"
```

## Bumping the image version

Each gallery image version is stamped `1.0.<unix>` from a `time_static`
resource. To produce a new version:

```sh
terraform apply \
  -replace=time_static.image_version \
  -var=trigger_build_on_apply=true
```

`replace_triggered_by` on the image template means the template is recreated
with the new version, and the `azapi_resource_action.build` then fires
`POST .../run` against the fresh template.

The GitHub Action does exactly this on its monthly schedule.

## Attaching the gallery to a Dev Center

After the first build completes, attach the gallery to your Dev Center so
Dev Box image definitions can reference it:

<https://learn.microsoft.com/azure/dev-box/how-to-configure-azure-compute-gallery>

Quick CLI version:

```sh
az devcenter admin gallery create \
  --dev-center-name <your-dev-center> \
  --resource-group <dev-center-rg> \
  --name <gallery-display-name> \
  --gallery-resource-id "$(terraform output -raw gallery_id)"
```

The Dev Center's managed identity needs the **Reader** role on the gallery.

## Referencing the image from `imagedefinition.yaml`

```yaml
# devbox-customizations / imagedefinition.yaml
$schema: 1.0
image: gal_devbox_images/win11-wsl-enabled@latest

tasks:
  # ...your tasks, no longer needing to enable optional features.
```

The exact reference string is in `terraform output devbox_image_reference`.

## GitHub Actions OIDC auth

`.github/workflows/rebuild-image.yml` uses federated credentials (no secrets).
Configure the federated identity on an app registration following
<https://learn.microsoft.com/azure/developer/github/connect-from-azure-openid-connect>
and set these repo secrets:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

## Cadence

The workflow runs on the **second Wednesday** of each month at 02:00 UTC
(`0 2 8-14 * 3`) — safely after Patch Tuesday — and pulls `latest` of the
base marketplace image. That way the custom image picks up new VS Enterprise
content, monthly Windows cumulative updates, and Defender definitions
without any manual intervention.

Manual rebuilds are available via the workflow's `workflow_dispatch` button.

## Dev Box-specific gotchas (commented in the code, summarised here)

- **Hyper-V Gen 2** (`hyper_v_generation = "V2"`) — Dev Box rejects Gen 1.
- **Generalized** (`specialized = false`) — Dev Box rejects specialized.
- **Trusted Launch** (`trusted_launch_enabled = true`) — Dev Box validates
  the image's Trusted Launch metadata and rejects images without it. See
  <https://learn.microsoft.com/azure/dev-box/how-to-troubleshoot-custom-image-validation>.
- **Explicit `WindowsRestart` after feature enablement** — without it,
  sysprep at the end of the build fails because CBS still has a pending
  transaction. This is the entire reason this repo exists.

[aib]: https://learn.microsoft.com/azure/virtual-machines/image-builder-overview
[devbox]: https://learn.microsoft.com/azure/dev-box/overview-what-is-microsoft-dev-box
