param(
    [string]$HubResourceGroupName = 'HUB',
    [string]$BlueResourceGroupName = 'Blue',
    [string]$RedResourceGroupName = 'Red',
    [string]$HubVnetName = 'hub-vnet',
    [switch]$DisableGatewayTransit
)

$ErrorActionPreference = 'Stop'

$common = @{
    HubResourceGroupName = $HubResourceGroupName
    HubVnetName = $HubVnetName
    DisableGatewayTransit = $DisableGatewayTransit
}

& "$PSScriptRoot\deploy-peering.ps1" @common -SpokeResourceGroupName $BlueResourceGroupName -SpokeVnetName 'blue-vnet'
& "$PSScriptRoot\deploy-peering.ps1" @common -SpokeResourceGroupName $RedResourceGroupName -SpokeVnetName 'red-vnet'
