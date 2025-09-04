<#!
.SYNOPSIS
  Deploy only the standalone Key Vault template.
.DESCRIPTION
  Wraps Test-AzResourceGroupDeployment and New-AzResourceGroupDeployment for bicep/keyvault/main.bicep
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ResourceGroupName,
    [Parameter(Mandatory = $true)][string]$Location,
    [Parameter(Mandatory = $false)][string]$ParameterFile = "./parameters/keyvault.dev.parameters.json",
    [switch]$WhatIf,
    [switch]$ShowParameters
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Log { param([string]$Message, [string]$Level = 'INFO'); Write-Host "[$Level] $Message" }

try {
    Write-Log "Starting Key Vault deployment"
    if (-not (Get-AzContext)) { Write-Log "Logging in interactively"; Connect-AzAccount | Out-Null }

    if (-not (Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue)) {
        Write-Log "Creating resource group $ResourceGroupName in $Location"; New-AzResourceGroup -Name $ResourceGroupName -Location $Location | Out-Null
    }

    Push-Location (Join-Path $PSScriptRoot '..')

    bicep build bicep/keyvault/main.bicep --outfile bicep/keyvault/main.json | Out-Null

    if ($WhatIf) {
        # Resolve and validate parameter file
        $paramPath = (Resolve-Path -Path $ParameterFile -ErrorAction SilentlyContinue)
        if (-not $paramPath) { Write-Log "Parameter file '$ParameterFile' not found" 'ERROR'; Pop-Location; exit 2 }
        Write-Log "Running Azure CLI what-if"
        $cliResult = az deployment group what-if --resource-group $ResourceGroupName --template-file bicep/keyvault/main.bicep --parameters @$paramPath 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Azure CLI what-if failed. Falling back to PowerShell WhatIf." 'ERROR'
            try {
                New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile bicep/keyvault/main.bicep -TemplateParameterFile $paramPath -WhatIf -ErrorAction Stop | Out-Host
            }
            catch {
                Write-Log "PowerShell WhatIf also failed: $($_.Exception.Message)" 'ERROR'
                Pop-Location; exit 3
            }
        } else { $cliResult | Out-Host }
        Pop-Location; return
    }

    $resolvedParamFile = (Resolve-Path -Path $ParameterFile -ErrorAction SilentlyContinue)
    if (-not $resolvedParamFile) { Write-Log "Parameter file '$ParameterFile' not found" 'ERROR'; Pop-Location; exit 2 }

    $null = Test-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile bicep/keyvault/main.bicep -TemplateParameterFile $resolvedParamFile -Mode Incremental -ErrorAction Stop
    Write-Log "Validation succeeded"

    $params = @{}
    if (Test-Path $resolvedParamFile) {
        $json = Get-Content -Raw -Path $resolvedParamFile | ConvertFrom-Json
        if ($json.parameters) { $json = $json.parameters }
        foreach ($k in $json.PSObject.Properties.Name) {
            $val = $json.$k
            if ($val -and $null -ne $val.value) { $params[$k] = $val.value } else { $params[$k] = $val }
        }
    }
    if ($ShowParameters) { Write-Log "Resolved parameters:`n$(($params|ConvertTo-Json -Depth 4))" }

    $deployment = New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile bicep/keyvault/main.bicep -Mode Incremental -TemplateParameterObject $params -Verbose
    $state = $deployment.ProvisioningState; if (-not $state -and $deployment.Properties) { $state = $deployment.Properties.ProvisioningState }
    if ($state -and $state -ne 'Succeeded') { Write-Log "Deployment state: $state" 'ERROR'; exit 4 }
    Write-Log "Key Vault deployment completed successfully" 'INFO'
    if ($deployment.Outputs) {
        Write-Log "Outputs:"; ($deployment.Outputs | ConvertTo-Json -Depth 5)
    }
    Pop-Location
}
catch { Write-Log "Unhandled error: $($_.Exception.Message)" 'ERROR'; exit 1 }
