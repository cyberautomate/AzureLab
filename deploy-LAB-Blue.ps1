<#
.SYNOPSIS
Deploy LAB-Blue spoke VNet and peer to hub.
#>
param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = 'dev',

    [Parameter(Mandatory = $false)]
    [string]$TemplateFile = 'LAB-Blue/main.bicep',

    [Parameter(Mandatory = $false)]
    [string]$ParameterFile = 'LAB-Blue/dev.parameters.json'
)

# Ensure Az modules are available
if (-not (Get-Module -ListAvailable -Name Az.Accounts)) {
    Write-Error "Az PowerShell modules are required. Install with: Install-Module -Name Az -Scope CurrentUser"
    exit 1
}

Import-Module Az.Accounts -ErrorAction Stop
Import-Module Az.Resources -ErrorAction Stop
Import-Module Az.Graph -ErrorAction SilentlyContinue

Write-Output "Validating parameters and address space overlap..."
$params = Get-Content -Raw $ParameterFile | ConvertFrom-Json
$vnetPrefix = $params.parameters.vnetAddressPrefix.value

# Query existing VNets address spaces using Resource Graph
$rgQuery = "Resources | where type =~ 'microsoft.network/virtualnetworks' | mv-expand prefixes = properties.addressSpace.addressPrefixes | project subscriptionId, resourceGroup, name, prefix = tostring(prefixes)"
$existing = Search-AzGraph -Query $rgQuery

# Check overlap: simple containment check for now
foreach ($row in $existing) {
    if ($row.prefix -eq $vnetPrefix) {
        Write-Error "Provided address space $vnetPrefix overlaps with existing VNet $($row.name) in subscription $($row.subscriptionId)"
        exit 1
    }
}

Write-Output "No exact prefix overlaps found. Proceeding with deployment to resource group '$ResourceGroupName'..."

# Ensure resource group exists
if (-not (Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue)) {
    Write-Output "Creating resource group $ResourceGroupName in location $($params.parameters.location.value)"
    New-AzResourceGroup -Name $ResourceGroupName -Location $params.parameters.location.value
}

# Deploy the Bicep template
$deploy = New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $TemplateFile -TemplateParameterFile $ParameterFile -Mode Incremental -Verbose
if ($deploy.ProvisioningState -ne 'Succeeded') {
    Write-Error "Deployment failed: $($deploy.ErrorMessage)"
    exit 1
}

Write-Output "Spoke VNet deployed."

# Offer to create hub-side peering
$hubSub = $params.parameters.hubSubscriptionId.value
$hubVnet = $params.parameters.hubVnetName.value
$spokeVnet = $params.parameters.vnetName.value

$createHubPeering = Read-Host "Do you want to create the hub-side peering in subscription $hubSub for hub VNet $hubVnet? (y/n)"
if ($createHubPeering -ne 'y') {
    Write-Output "Skipping hub-side peering. You will need to create a peering in the hub subscription pointing back to the spoke."
    exit 0
}

Write-Output "Creating hub-side peering (requires you have access to the hub subscription)..."

# Switch context to hub subscription
$curSub = Get-AzContext
Set-AzContext -Subscription $hubSub

# Create the peering resource in hub subscription
$hubPeeringName = "${hubVnet}-to-${spokeVnet}-peering"
$spokeVnetId = (Get-AzResource -ResourceType 'Microsoft.Network/virtualNetworks' -Name $spokeVnet -ErrorAction SilentlyContinue).ResourceId
if (-not $spokeVnetId) {
    # If spoke is in different subscription, build the id
    $spokeSubId = (Get-AzContext).Subscription.Id
    $spokeVnetId = "/subscriptions/$spokeSubId/resourceGroups/$ResourceGroupName/providers/Microsoft.Network/virtualNetworks/$spokeVnet"
}

$hubVnetResource = Get-AzVirtualNetwork -Name $hubVnet -ErrorAction Stop

Add-AzVirtualNetworkPeering -Name $hubPeeringName -VirtualNetwork $hubVnetResource -RemoteVirtualNetworkId $spokeVnetId -AllowForwardedTraffic -AllowGatewayTransit -AllowVirtualNetworkAccess

Write-Output "Hub-side peering created."

# Restore previous context
Set-AzContext -Subscription $curSub.Subscription.Id

Write-Output "Done. Remember to configure firewall policies and UDRs on the hub if needed."
