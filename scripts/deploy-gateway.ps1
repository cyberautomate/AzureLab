param(
    [string]$ResourceGroupName = 'hub',
    [string]$Location = 'westus2',
    [string]$DeploymentName = 'hub-gateway',
    [string]$KeyVaultName = 'dahalllab-dev-kv',
    [string]$VnetName = 'hub-vnet',
    [string]$GatewayName = 'hub-vpngw',
    [string]$PublicIpName = 'hub-vpngw-pip',
    [string]$GatewaySku = 'VpnGw1',
    [string]$ClientAddressPool = '172.16.201.0/24',
    [string[]]$VpnClientProtocols = @('OpenVPN'),
    [string]$DeploymentTemplate = '..\bicep\hub\gateway.bicep',
    [switch]$AutoDeleteConflicts,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
Write-Host "== VPN Gateway Deployment ==" -ForegroundColor Cyan

if (-not (Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue)) {
    throw "Resource group $ResourceGroupName not found. Deploy hub first."
}

$templateFile = Join-Path $PSScriptRoot $DeploymentTemplate
if (-not (Test-Path $templateFile)) { throw "Template not found: $templateFile" }

# Secrets
$secretNames = @('aadTenantId', 'aadAudience')
$kvSecrets = @{}
foreach ($s in $secretNames) {
    $sec = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $s -ErrorAction Stop
    if ([string]::IsNullOrWhiteSpace($sec.SecretValueText)) { throw "Secret '$s' is empty in Key Vault '$KeyVaultName'" }
    $kvSecrets[$s] = $sec.SecretValueText
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
