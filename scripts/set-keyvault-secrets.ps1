<#!
.SYNOPSIS
  Bulk create or update Azure Key Vault secrets from inline values, a JSON file, or environment variables.
.DESCRIPTION
  Provides multiple input mechanisms to populate a Key Vault without hardcoding secrets in source.
  Supports:
    -Explicit -Secrets hashtable (Name=Value)
    -JsonFile path containing { "name":"value", ... }
    -EnvPrefix to import all environment variables whose names start with the prefix

  Uses Az.KeyVault module cmdlets. Assumes caller has appropriate RBAC (e.g. Key Vault Secrets User).
.PARAMETER VaultName
  Name of the existing Key Vault.
.PARAMETER Secrets
  Hashtable of Name=Value pairs.
.PARAMETER JsonFile
  Path to JSON file containing a flat object mapping secret names to values.
.PARAMETER EnvPrefix
  Prefix used to select environment variables (case-insensitive) to import as secrets.
.PARAMETER Replace
  Overwrite existing secrets (default true). If false and secret exists, skip.
.PARAMETER WhatIf
  Show actions without creating secrets.
.EXAMPLE
  ./set-keyvault-secrets.ps1 -VaultName myproj-dev-kv -Secrets @{ aadAppClientId='11111111-1111-1111-1111-111111111111'; platformAdminObjectId='2222...' }
.EXAMPLE
  ./set-keyvault-secrets.ps1 -VaultName myproj-dev-kv -JsonFile ./secrets.dev.json
.EXAMPLE
  $env:INFRA_AADAPPID='1111'; $env:INFRA_PLATFORMADMIN='2222'; ./set-keyvault-secrets.ps1 -VaultName myproj-dev-kv -EnvPrefix INFRA_
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)][string]$VaultName,
    [hashtable]$Secrets,
    [string]$JsonFile,
    [string]$EnvPrefix,
    [switch]$Replace = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Log { param([string]$Message, [string]$Level = 'INFO'); Write-Host "[$Level] $Message" }

function Merge-SecretsSource {
    param([hashtable]$Target, [hashtable]$Source, [string]$Label)
    if (-not $Source) { return }
    foreach ($k in $Source.Keys) { $Target[$k] = $Source[$k] }
    Write-Log "Loaded $($Source.Count) secrets from $Label"
}

if (-not (Get-AzContext)) { Write-Log 'No Az context found, attempting login'; Connect-AzAccount | Out-Null }

# Accumulate secrets
$all = @{}
if ($Secrets) { Merge-SecretsSource -Target $all -Source $Secrets -Label 'parameter -Secrets' }
if ($JsonFile) {
    if (-not (Test-Path $JsonFile)) { throw "JsonFile '$JsonFile' not found" }
    $jsonObj = Get-Content -Raw -Path $JsonFile | ConvertFrom-Json
    if ($jsonObj -isnot [pscustomobject]) { throw 'JSON root must be an object of name:value pairs' }
    $ht = @{}
    foreach ($p in $jsonObj.PSObject.Properties) { $ht[$p.Name] = $p.Value }
    Merge-SecretsSource -Target $all -Source $ht -Label "JSON file $JsonFile"
}
if ($EnvPrefix) {
    $filtered = Get-ChildItem Env: | Where-Object { $_.Name.ToUpper().StartsWith($EnvPrefix.ToUpper()) }
    $ht = @{}
    foreach ($e in $filtered) {
        $name = $e.Name.Substring($EnvPrefix.Length)
        if ($name) { $ht[$name] = $e.Value }
    }
    Merge-SecretsSource -Target $all -Source $ht -Label "environment prefix $EnvPrefix"
}

if ($all.Count -eq 0) { Write-Log 'No secrets to process' 'WARN'; return }

Write-Log "Processing $($all.Count) secrets for vault $VaultName"

foreach ($name in $all.Keys) {
    $value = [string]$all[$name]
    if (-not $value) { Write-Log "Skipping '$name' (empty value)" 'WARN'; continue }
    $exists = $false
    try { $null = Get-AzKeyVaultSecret -VaultName $VaultName -Name $name -ErrorAction Stop; $exists = $true } catch { $exists = $false }
    if ($exists -and -not $Replace) { Write-Log "Skipping existing secret '$name' (Replace disabled)"; continue }
    $secure = ConvertTo-SecureString $value -AsPlainText -Force
    if ($PSCmdlet.ShouldProcess("$VaultName/$name", 'Set secret')) {
        Set-AzKeyVaultSecret -VaultName $VaultName -Name $name -SecretValue $secure | Out-Null
        Write-Log "Set secret '$name' (exists=$exists)"
    }
}

Write-Log 'Completed secret operations'
