# Stage — Spoke Blue deployment runbook

This runbook describes deploying the Blue spoke virtual network and subnets.

Resources provisioned:

- Blue VNet `blue-vnet` with address space `10.0.4.0/22`
- Subnets:
  - `blue-vm-subnet-1` (10.0.4.0/24)
  - `blue-vm-subnet-2` (10.0.5.0/24)
  - `blue-container-subnet` (10.0.6.0/24) with delegation to `Microsoft.ContainerInstance/containerGroups`

## Pre-reqs

- Hub network deployed (for future peering, if required)
- Azure CLI and Bicep installed, logged in to the correct subscription

## WhatIf Preview

```powershell
pwsh -File .\scripts\deploy-spoke-blue.ps1 -ResourceGroupName Blue -Location westus2 -WhatIf
```

## Deploy

```powershell
pwsh -File .\scripts\deploy-spoke-blue.ps1 -ResourceGroupName Blue -Location westus2
```

Optional: add tags

```powershell
pwsh -File .\scripts\deploy-spoke-blue.ps1 -ResourceGroupName Blue -Location westus2 -Tags @{ environment = 'Dev'; owner = 'NetOps' }
```

## Post-Deployment Validation

```powershell
az network vnet show --resource-group Blue --name blue-vnet --query "{addressSpace:addressSpace.addressPrefixes, subnets:subnets[].{name:name,prefix:addressPrefix,delegations:delegations[].serviceName}}" -o table
```

Ensure the three subnets exist and the container subnet has the ACI delegation. Add peering to hub as a separate step (not yet automated here).

## Notes

- Parameter file not required; only optional `tags` are accepted.
- Deployment script creates the resource group if missing.
- Peering intentionally separate to allow staged environment creation.
