# Spoke Red deployment runbook

This runbook describes deploying the Red spoke virtual network and subnets.

Resources provisioned:

- Red VNet `red-vnet` with address space `10.0.8.0/22`
- Subnets:
  - `red-vm-subnet-1` (10.0.8.0/24)
  - `red-vm-subnet-2` (10.0.9.0/24)
  - `red-container-subnet` (10.0.10.0/24) with delegation to `Microsoft.ContainerInstance/containerGroups`

## Pre-reqs

- Hub network deployed (for future peering)
- Azure CLI & Bicep installed and authenticated

## WhatIf Preview

```powershell
pwsh -File .\scripts\deploy-spoke-red.ps1 -ResourceGroupName Red -Location westus2 -WhatIf
```

## Deploy

```powershell
pwsh -File .\scripts\deploy-spoke-red.ps1 -ResourceGroupName Red -Location westus2
```

Optional with tags:

```powershell
pwsh -File .\scripts\deploy-spoke-red.ps1 -ResourceGroupName Red -Location westus2 -Tags @{ environment = 'Dev'; owner = 'NetOps' }
```

## Post-Deployment Validation

```powershell
az network vnet show --resource-group Red --name red-vnet --query "{addressSpace:addressSpace.addressPrefixes, subnets:subnets[].{name:name,prefix:addressPrefix,delegations:delegations[].serviceName}}" -o table
```

Ensure all three subnets exist and container subnet has delegation.

## Root Template Option

Deploy via root template with both spokes:

```powershell
az deployment group create --resource-group <rg> --template-file bicep/main.bicep --parameters namePrefix=lab environment=dev deployBlueVnet=true deployRedVnet=true
```

## Notes

- Parameter file not required for spoke templates (only optional tags).
- Peering handled separately.
