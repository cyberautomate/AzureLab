param(
    [string]$ResourceGroupName = 'blue',
    [string]$Location = 'westus2',
    [string]$DeploymentName = 'spoke-blue',
    [object]$Tags = @{},
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
Write-Host "== Spoke Blue Deployment ==" -ForegroundColor Cyan

# Ensure RG exists
if (-not (Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue)) {
    Write-Host "Creating resource group $ResourceGroupName in $Location" -ForegroundColor Yellow
    New-AzResourceGroup -Name $ResourceGroupName -Location $Location -Tag $Tags | Out-Null
}

$templateFile = Join-Path $PSScriptRoot '..\bicep\spoke-blue\main.bicep'
if (-not (Test-Path $templateFile)) { throw "Template not found: $templateFile" }

$params = @{}
if ($Tags -and $Tags.Keys.Count -gt 0) { $params['tags'] = $Tags }

$mode = 'Incremental'
if ($WhatIf) {
    Write-Host 'Running WhatIf...' -ForegroundColor DarkCyan
    New-AzResourceGroupDeployment -Name ($DeploymentName + '-whatif') -ResourceGroupName $ResourceGroupName -TemplateFile $templateFile -TemplateParameterObject $params -Mode $mode -WhatIf
    return
}

Write-Host "Deploying Spoke Blue (VNet + subnets) ..." -ForegroundColor Green
New-AzResourceGroupDeployment -Name $DeploymentName -ResourceGroupName $ResourceGroupName -TemplateFile $templateFile -TemplateParameterObject $params -Mode $mode -Verbose
