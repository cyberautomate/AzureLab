# Inputs
$ResourceGroupName = 'hub'           # adjust
$Location = 'westus2'        # or from hub.parameters.json
$KeyVaultName = 'dahalllab-dev-kv'
$HubParamFile = 'bicep/parameters/hub.parameters.json'

# Secrets expected in Key Vault
$secretNames = @('aadTenantId', 'aadAudience')

# Load base parameter file
if (-not (Test-Path $HubParamFile)) { throw "Parameter file not found: $HubParamFile" }
$raw = Get-Content -Raw -Path $HubParamFile | ConvertFrom-Json
$paramRoot = if ($raw.parameters) { $raw.parameters } else { $raw }

# Resolve secrets
$secretValues = @{}
foreach ($s in $secretNames) {
    $sec = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $s -ErrorAction Stop
    $secretValues[$s] = $sec.SecretValueText
}

# Merge secrets into vpnP2S object (create if missing)
if (-not $paramRoot.vpnP2S) {
    $paramRoot.vpnP2S = @{
        value = @{
            authenticationType = 'AzureAD'
            aadTenantId        = ''
            aadAudience        = ''
            clientAddressPool  = '172.16.201.0/24'
            vpnClientProtocols = @('OpenVPN', 'IkeV2')
        }
    }
}

# If file uses value wrappers
$vpnObj = if ($paramRoot.vpnP2S.value) { $paramRoot.vpnP2S.value } else { $paramRoot.vpnP2S }

$vpnObj.aadTenantId = $secretValues.aadTenantId
$vpnObj.aadAudience = $secretValues.aadAudience

# Build final template parameter hashtable (flatten value wrappers)
$deployParams = @{}
foreach ($p in $paramRoot.PSObject.Properties.Name) {
    $entry = $paramRoot.$p
    if ($entry -and $entry.value -ne $null) {
        $deployParams[$p] = $entry.value
    }
    else {
        $deployParams[$p] = $entry
    }
}

# Validate template (WhatIf optional)
Test-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName `
    -TemplateFile bicep/hub/main.bicep `
    -TemplateParameterObject $deployParams `
    -Mode Incremental | Out-Null

New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName `
    -TemplateFile bicep/hub/main.bicep `
    -TemplateParameterObject $deployParams `
    -Mode Incremental -Verbose