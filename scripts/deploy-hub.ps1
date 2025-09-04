param(
    [string]$ResourceGroupName = 'hub',
    [string]$Location = 'westus2',
    [string]$DeploymentName = 'hub-core',
    [string]$FirewallTier = 'Basic',
    [switch]$AutoDeleteConflicts,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
Write-Host "== Hub Core Deployment (no VPN Gateway) ==" -ForegroundColor Cyan

# Ensure RG exists
if (-not (Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue)) {
    Write-Host "Creating resource group $ResourceGroupName in $Location" -ForegroundColor Yellow
    New-AzResourceGroup -Name $ResourceGroupName -Location $Location | Out-Null
}

$templateFile = Join-Path $PSScriptRoot '..\bicep\hub\main.bicep'
if (-not (Test-Path $templateFile)) { throw "Template not found: $templateFile" }

# Pre-flight: detect existing firewall and tier mismatch
$fw = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType Microsoft.Network/azureFirewalls -Name 'hub-firewall' -ErrorAction SilentlyContinue
if ($fw) {
    $current = ($fw.Properties.sku.tier)
    if ($current -and $current -ne $FirewallTier) {
        Write-Warning "Existing firewall tier '$current' differs from requested '$FirewallTier'. In-place change not supported."    
        if ($AutoDeleteConflicts) {
            Write-Host "AutoDeleteConflicts set. Removing existing firewall + public IP..." -ForegroundColor Yellow
            Remove-AzResource -ResourceId $fw.ResourceId -Force
            $pip = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType Microsoft.Network/publicIPAddresses -Name 'hub-firewall-pip' -ErrorAction SilentlyContinue
            if ($pip) { Remove-AzResource -ResourceId $pip.ResourceId -Force }
        }
        else {
            throw "Conflict: firewall tier mismatch. Rerun with -AutoDeleteConflicts to recreate."
        }
    }
}

$params = @{
    firewallTier = $FirewallTier
}

Write-Verbose ("Parameter object: {0}" -f ($params | ConvertTo-Json -Compress))

$mode = 'Incremental'
if ($WhatIf) {
    Write-Host "Running WhatIf..." -ForegroundColor DarkCyan
    New-AzResourceGroupDeployment -Name ($DeploymentName + '-whatif') -ResourceGroupName $ResourceGroupName -TemplateFile $templateFile -TemplateParameterObject $params -Mode $mode -WhatIf
    return
}

Write-Host "Deploying hub core (tier: $FirewallTier)..." -ForegroundColor Green
New-AzResourceGroupDeployment -Name $DeploymentName -ResourceGroupName $ResourceGroupName -TemplateFile $templateFile -TemplateParameterObject $params -Mode $mode -Verbose
