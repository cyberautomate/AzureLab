param(
    [string]$ResourceGroupName = 'Red',
    [string]$Location = 'westus2',
    [string]$DeploymentName = 'spoke-red',
    [object]$Tags = @{},
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
Write-Host "== Spoke Red Deployment ==" -ForegroundColor Cyan

# Ensure RG exists
if (-not (Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue)) {
    Write-Host "Creating resource group $ResourceGroupName in $Location" -ForegroundColor Yellow
    New-AzResourceGroup -Name $ResourceGroupName -Location $Location -Tag $Tags | Out-Null
}

$templateFile = Join-Path $PSScriptRoot '..\bicep\spoke-red\main.bicep'
if (-not (Test-Path $templateFile)) { throw "Template not found: $templateFile" }

$params = @{}
if ($Tags -and $Tags.Keys.Count -gt 0) { $params['tags'] = $Tags }

$mode = 'Incremental'
if ($WhatIf) {
    Write-Host 'Running WhatIf...' -ForegroundColor DarkCyan
    New-AzResourceGroupDeployment -Name ($DeploymentName + '-whatif') -ResourceGroupName $ResourceGroupName -TemplateFile $templateFile -TemplateParameterObject $params -Mode $mode -WhatIf
    return
}

Write-Host "Deploying Spoke Red (VNet + subnets) ..." -ForegroundColor Green
New-AzResourceGroupDeployment -Name $DeploymentName -ResourceGroupName $ResourceGroupName -TemplateFile $templateFile -TemplateParameterObject $params -Mode $mode -Verbose
