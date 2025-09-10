param(
    [Parameter(Mandatory=$true)][string]$HubResourceGroupName = 'HUB',
    [Parameter(Mandatory=$true)][string]$SpokeResourceGroupName,
    [Parameter(Mandatory=$true)][ValidateSet('blue-vnet','red-vnet')][string]$SpokeVnetName,
    [string]$HubVnetName = 'hub-vnet',
    [switch]$DisableGatewayTransit
)

$ErrorActionPreference = 'Stop'
Write-Host "== Deploying VNet Peering ($SpokeVnetName <-> $HubVnetName) ==" -ForegroundColor Cyan

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Join-Path $scriptRoot '..'
$templateFile = Join-Path $repoRoot 'bicep/peering/connect-spoke-to-hub.bicep'
if (-not (Test-Path $templateFile)) { throw "Template not found: $templateFile" }

$enableGatewayTransit = -not $DisableGatewayTransit.IsPresent

# Determine a location for subscription-scoped deployment: prefer Hub RG location, then Spoke RG location, else fallback to first available location
$location = $null
try {
    $hubRg = Get-AzResourceGroup -Name $HubResourceGroupName -ErrorAction SilentlyContinue
    if ($hubRg) { $location = $hubRg.Location }
}
catch { }

if (-not $location) {
    try {
        $spokeRg = Get-AzResourceGroup -Name $SpokeResourceGroupName -ErrorAction SilentlyContinue
        if ($spokeRg) { $location = $spokeRg.Location }
    }
    catch { }
}

if (-not $location) {
    # Fallback: pick the first registered location for the subscription
    $loc = (Get-AzLocation | Select-Object -First 1)
    if ($loc) { $location = $loc.Name }
}

if (-not $location) { throw 'Unable to determine a valid location for subscription-scoped deployment. Ensure Az module is logged in.' }

$cmd = @(
    'deployment','sub','create',
    '--location',$location,
    '--template-file',$templateFile,
    '--parameters',"hubResourceGroupName=$HubResourceGroupName",
    '--parameters',"spokeResourceGroupName=$SpokeResourceGroupName",
    '--parameters',"spokeVnetName=$SpokeVnetName",
    '--parameters',"hubVnetName=$HubVnetName",
    '--parameters',"enableGatewayTransit=$enableGatewayTransit"
)

Write-Host "Running: az $($cmd -join ' ')" -ForegroundColor DarkCyan
az @cmd | Write-Output
