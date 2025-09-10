# Deploy devSVR VM (Trusted Launch) - dev resource group

This document explains how to deploy the `devSVR` Trusted Launch Windows VM into the existing `Dev` resource group using the supplied Bicep module.

Files added

- `bicep/modules/vmWindowsTrustedLaunch.bicep` - VM module (NIC + VM)

- `bicep/dev-vm.bicep` - deployment wrapper that calls the module with dev defaults

- `parameters/dev-vm.parameters.json` - parameters file (contains placeholder for password)

Assumptions and notes

- VM image selected: MicrosoftWindowsServer:WindowsServer:2025-datacenter-gen2:latest. Marketplace SKUs can vary by region; if this SKU is not available use `az vm image list --publisher MicrosoftWindowsServer --offer WindowsServer --all` to find the correct SKU.

- The virtual network `labblue-spoke-vnet` and subnet `default` must already exist in the target resource group or be reachable as an existing resource in the same subscription.

- No public IP is created by this module; VM will be private on the chosen subnet.

- Accelerated networking is enabled on the NIC via the module parameter. The selected VM size must support accelerated networking.

- License type is set to `Windows_Server` (the user indicated they already have a Windows license).

- Admin password must meet Windows complexity rules; update `parameters/dev-vm.parameters.json` before deploying.

- Auto-shutdown, backup, site recovery, and other features are intentionally not configured to match the requested spec.

Deploy

1. Edit `parameters/dev-vm.parameters.json` and set a strong password for `adminPassword`.
2. From a shell with Azure CLI authenticated (the default subscription should be the Hub subscription where the Dev resource group exists), run:

```powershell
az deployment group create --resource-group Dev --template-file bicep/dev-vm.bicep --parameters @parameters/dev-vm.parameters.json
```

If you need to specify a different subscription, set `AZURE_SUBSCRIPTION_ID` or use `--subscription` on the `az` command.

Troubleshooting

- If the image SKU is unavailable, select the correct SKU for your region and update `bicep/dev-vm.bicep` image parameters.

- If accelerated networking fails to enable, either choose a supported VM size or set `enableAcceleratedNetworking` to `false` in `bicep/dev-vm.bicep`.

Security

- Don't store real passwords in source control. Use secure parameter passing or a Key Vault reference in CI.
