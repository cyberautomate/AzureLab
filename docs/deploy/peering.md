# Hub <-> Spoke VNet Peering Runbook

This runbook covers creating virtual network peerings between the Hub VNet and the spoke VNets (Blue, Red).

Peering configuration (defaults):

- allowVirtualNetworkAccess: true (both directions)
- allowForwardedTraffic: true (both directions)
- gatewayTransit: enabled (Hub allows gateway transit; Spoke uses remote gateways) unless -DisableGatewayTransit is specified

## Prerequisites

- Hub `hub-vnet` deployed in resource group `HUB`
- Spokes `blue-vnet` in `Blue` and `red-vnet` in `Red`
- Azure CLI and Bicep installed and authenticated

## Deploy peering for a single spoke

```powershell
pwsh -File .\scripts\deploy-peering.ps1 -HubResourceGroupName HUB -SpokeResourceGroupName Blue -SpokeVnetName blue-vnet
```

Disable gateway transit:

```powershell
pwsh -File .\scripts\deploy-peering.ps1 -HubResourceGroupName HUB -SpokeResourceGroupName Blue -SpokeVnetName blue-vnet -DisableGatewayTransit
```

## Deploy peering for both Blue and Red

```powershell
pwsh -File .\scripts\deploy-all-peerings.ps1 -HubResourceGroupName HUB -BlueResourceGroupName Blue -RedResourceGroupName Red
```

## Deploy using Azure CLI directly

```powershell
az deployment sub create --location westus2 --template-file bicep/peering/connect-spoke-to-hub.bicep --parameters hubResourceGroupName=HUB spokeResourceGroupName=Blue spokeVnetName=blue-vnet hubVnetName=hub-vnet
```

## Validation

```powershell
az network vnet peering list --resource-group HUB --vnet-name hub-vnet -o table
az network vnet peering list --resource-group Blue --vnet-name blue-vnet -o table
az network vnet peering list --resource-group Red --vnet-name red-vnet -o table
```
