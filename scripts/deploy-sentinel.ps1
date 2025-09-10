param(
    [string]$ResourceGroupName = 'HUB',
    [string]$Location = 'westus2',
    [string]$WorkspaceName = 'hub-law',
    [switch]$WhatIf,
    [switch]$UseArmJson
)

$ErrorActionPreference = 'Stop'
Write-Host "== Deploying Microsoft Sentinel (Log Analytics workspace + Sentinel) ==" -ForegroundColor Cyan

try {
    # Ensure RG exists
    if (-not (Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue)) {
        Write-Host "Creating resource group $ResourceGroupName in $Location" -ForegroundColor Yellow
        New-AzResourceGroup -Name $ResourceGroupName -Location $Location | Out-Null
    }

    if ($UseArmJson) {
        $templateFile = Join-Path $PSScriptRoot '..\bicep\hub\sentinel.json'
    }
    else {
        # prefer deploying Bicep directly (allows template compilation during deployment)
        $templateFile = Join-Path $PSScriptRoot '..\bicep\hub\sentinel.bicep'
    }

    if (-not (Test-Path $templateFile)) { throw "Template not found: $templateFile" }

    $paramArgs = "workspaceName=$WorkspaceName"

    if ($WhatIf) {
        Write-Host 'Running WhatIf...' -ForegroundColor DarkCyan
        az deployment group what-if --resource-group $ResourceGroupName --template-file $templateFile --parameters $paramArgs | Write-Output
        return
    }

    Write-Host "Deploying Sentinel to resource group '$ResourceGroupName' using template '$templateFile'..." -ForegroundColor Green
    az deployment group create --resource-group $ResourceGroupName --template-file $templateFile --parameters $paramArgs | Write-Output
}
catch {
    Write-Host "Deployment failed: $($_.Exception.Message)" -ForegroundColor Red
    throw
}
