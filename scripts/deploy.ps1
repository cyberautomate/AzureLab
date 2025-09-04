<#
.SYNOPSIS
    Deploys bicep/main.bicep into a resource group after validation and a WhatIf test.

.NOTES
    Requires Az PowerShell module. For CI, authenticate with a service principal or managed identity.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string] $Location,

    [Parameter(Mandatory = $false)]
    [string] $ParameterFile = "./parameters/dev.parameters.json",

    [Parameter(Mandatory = $false)]
    [string] $KeyVaultName,

    [Parameter(Mandatory = $false)]
    [string[]] $SecretNames = @(),

    [switch] $ShowResolvedParameters,

    [switch] $WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    Write-Host "[$Level] $Message"
}

try {
    Write-Log "Starting deployment script"

    if (-not (Get-Module -Name 'Az.Accounts' -ErrorAction SilentlyContinue)) {
        Write-Log "Az module not found. Please install Az.PowerShell module." 'ERROR'
        exit 2
    }

    # Authenticate - prefer managed identity or service principal in CI
    if (-not (Get-AzContext)) {
        Write-Log "No Az context found. Attempting interactive login..."
        Connect-AzAccount | Out-Null
    }

    # Ensure resource group exists
    if (-not (Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue)) {
        Write-Log "Creating resource group $ResourceGroupName in $Location"
        New-AzResourceGroup -Name $ResourceGroupName -Location $Location | Out-Null
    }

    Push-Location -Path (Join-Path -Path $PSScriptRoot -ChildPath '..')

    Write-Log "Building Bicep file"
    bicep build bicep/main.bicep --outfile bicep/main.json

    Write-Log "Validating (WhatIf/Test)"
    if ($WhatIf) {
        az deployment group what-if --resource-group $ResourceGroupName --template-file bicep/main.bicep --parameters @$ParameterFile | Write-Output
        Write-Log "WhatIf complete. Exiting per flag." 'INFO'
        Pop-Location
        exit 0
    }

    $validationSucceeded = $false
    try {
        $null = Test-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile bicep/main.bicep -TemplateParameterFile $ParameterFile -Mode Incremental -ErrorAction Stop
        $validationSucceeded = $true
        Write-Log "Template validation (Test-AzResourceGroupDeployment) succeeded"
    }
    catch {
        Write-Log "Template validation failed: $($_.Exception.Message)" 'ERROR'
        Pop-Location
        exit 3
    }

    Write-Log "Starting deployment"
    # Build parameter hashtable combining file parameters with secrets (if provided)
    $templateParams = @{}
    if (Test-Path $ParameterFile) {
        $json = Get-Content -Raw -Path $ParameterFile | ConvertFrom-Json
        if ($json.parameters) { $json = $json.parameters }
        foreach ($k in $json.PSObject.Properties.Name) {
            $val = $json.$k
            if ($val -and $val.value -ne $null) { $templateParams[$k] = $val.value } else { $templateParams[$k] = $val }
        }
    }

    if ($KeyVaultName -and $SecretNames.Count -gt 0) {
        Write-Log "Resolving secrets from Key Vault '$KeyVaultName'" 'INFO'
        foreach ($s in $SecretNames) {
            try {
                $secret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $s -ErrorAction Stop
                $templateParams[$s] = ($secret.SecretValueText)
            }
            catch {
                Write-Log "Failed to retrieve secret ${s}: $($_.Exception.Message)" 'ERROR'
                throw
            }
        }
    }

    if ($ShowResolvedParameters) {
        Write-Log "Resolved parameters:`n$(($templateParams | ConvertTo-Json -Depth 4))" 'INFO'
    }

    # Convert hashtable to @{
    $flat = @()
    foreach ($kvp in $templateParams.GetEnumerator()) { $flat += "${kvp.Key}=${kvp.Value}" }

    $deployment = New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile bicep/main.bicep -Mode Incremental -Verbose -TemplateParameterObject $templateParams

    $provState = $deployment.ProvisioningState
    if (-not $provState -and $deployment.Properties) { $provState = $deployment.Properties.ProvisioningState }
    if (-not $provState) { Write-Log "ProvisioningState not exposed; assuming success if no exception was thrown." }

    if ($provState -and $provState -ne 'Succeeded') {
        Write-Log "Deployment reported state: $provState" 'ERROR'
        Write-Log ($deployment | ConvertTo-Json -Depth 5) 'ERROR'
        Pop-Location
        exit 4
    }

    Write-Log "Deployment completed successfully" 'INFO'
    Pop-Location
    exit 0

}
catch {
    Write-Log "Unhandled error: $($_.Exception.Message)" 'ERROR'
    exit 1
}
