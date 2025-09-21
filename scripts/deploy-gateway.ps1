param(
    [string]$ResourceGroupName = 'hub',
    [string]$Location = 'westus2',
    [string]$DeploymentName = 'hub-vpngateway',
    [string]$KeyVaultName = 'dahalllab-dev-kv',
    [string]$VnetName = 'hub-vnet',
    [string]$GatewayName = 'hub-vpngw',
    [string]$PublicIpName = 'hub-vpngw-pip',
    [string]$GatewaySku = 'VpnGw1',
    [string]$ClientAddressPool = '172.16.201.0/24',
    [string[]]$VpnClientProtocols = @('OpenVPN'),
    [string]$DeploymentTemplate = '..\bicep\hub\gateway.bicep',
    [switch]$AutoDeleteConflicts,
    [switch]$WhatIf,
    [switch]$DebugSecrets
)

$ErrorActionPreference = 'Stop'
Write-Host "== VPN Gateway Deployment ==" -ForegroundColor Cyan

if (-not (Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue)) {
    throw "Resource group $ResourceGroupName not found. Deploy hub first."
}

$templateFile = Join-Path $PSScriptRoot $DeploymentTemplate
if (-not (Test-Path $templateFile)) { throw "Template not found: $templateFile" }

# Secrets (AAD P2S requirements). We aggregate all issues then throw once for better UX.
$secretNames = @('aadTenantId', 'aadAudience')
$kvSecrets = @{}
$missing = @()
$empty = @()
foreach ($s in $secretNames) {
    try {
        $sec = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $s -ErrorAction Stop
        $val = $sec.SecretValueText
        if ([string]::IsNullOrWhiteSpace($val)) {
            # Fallback: some Az versions can return blank SecretValueText even when value exists (rare / edge). Try secure string marshal.
            try {
                $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec.SecretValue)
                $val = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
            }
            catch { }
        }
        if ([string]::IsNullOrWhiteSpace($val)) { $empty += $s }
        else {
            $val = $val.Trim()
            # Simple GUID pattern check for aadTenantId only
            if ($s -eq 'aadTenantId') {
                $isGuid = ($val.Length -eq 36 -and $val[8] -eq '-' -and $val[13] -eq '-' -and $val[18] -eq '-' -and $val[23] -eq '-')
                if (-not $isGuid -and $DebugSecrets) { Write-Warning "aadTenantId secret does not look like a GUID; value will be passed as-is (len=$($val.Length))" }
            }
            $kvSecrets[$s] = $val
            if ($DebugSecrets) { Write-Verbose "Retrieved secret $s (length=$($val.Length))" }
        }
    }
    catch {
        $missing += $s
    }
}
if ($missing.Count -gt 0 -or $empty.Count -gt 0) {
    $msg = @()
    if ($missing.Count -gt 0) { $msg += "Missing secrets: $($missing -join ', ')" }
    if ($empty.Count -gt 0) { $msg += "Empty secrets: $($empty -join ', ')" }
    $msg += "Key Vault: $KeyVaultName"
    $msg += "Populate with: set-keyvault-secrets.ps1 -VaultName $KeyVaultName -Secrets @{ aadTenantId='<<tenant-guid>>'; aadAudience='<<server-app-id>>' }"
    if ($DebugSecrets) {
        $msg += "Debug details: Az module version = $((Get-Module Az.KeyVault -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).Version)"
    }
    throw ($msg -join '; ')
}

# Existing gateway conflict detection
$gw = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType Microsoft.Network/virtualNetworkGateways -Name $GatewayName -ErrorAction SilentlyContinue
if ($gw) {
    $currentSku = $gw.Properties.sku.name
    if ($currentSku -and $currentSku -ne $GatewaySku) {
        Write-Warning "Existing gateway SKU '$currentSku' differs from requested '$GatewaySku'. In-place change may fail."    
        if ($AutoDeleteConflicts) {
            Write-Host "Removing existing gateway + public IP (AutoDeleteConflicts)..." -ForegroundColor Yellow
            Remove-AzResource -ResourceId $gw.ResourceId -Force
            $pip = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType Microsoft.Network/publicIPAddresses -Name $PublicIpName -ErrorAction SilentlyContinue
            if ($pip) { Remove-AzResource -ResourceId $pip.ResourceId -Force }
        }
        else { throw "Conflict: gateway SKU mismatch. Rerun with -AutoDeleteConflicts to recreate." }
    }
}

$vpnP2S = @{
    authenticationType = 'AzureAD'
    aadTenantId        = $kvSecrets.aadTenantId
    aadAudience        = $kvSecrets.aadAudience
    clientAddressPool  = $ClientAddressPool
    vpnClientProtocols = $VpnClientProtocols
}

$params = @{
    vnetName     = $VnetName
    gatewayName  = $GatewayName
    publicIpName = $PublicIpName
    gatewaySku   = $GatewaySku
    vpnP2S       = $vpnP2S
}

Write-Verbose ("Parameter object: {0}" -f ($params | ConvertTo-Json -Compress))

$mode = 'Incremental'
if ($WhatIf) {
    Write-Host "Running WhatIf for gateway..." -ForegroundColor DarkCyan
    New-AzResourceGroupDeployment -Name ($DeploymentName + '-whatif') -ResourceGroupName $ResourceGroupName -TemplateFile $templateFile -TemplateParameterObject $params -Mode $mode -WhatIf
    return
}

Write-Host "Deploying VPN Gateway..." -ForegroundColor Green
New-AzResourceGroupDeployment -Name $DeploymentName -ResourceGroupName $ResourceGroupName -TemplateFile $templateFile -TemplateParameterObject $params -Mode $mode -Verbose
