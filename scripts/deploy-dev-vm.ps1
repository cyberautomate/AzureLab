<#
.SYNOPSIS
  Deploy the Dev Trusted Launch Windows VM using the bicep module `bicep/dev-vm.bicep`.

.DESCRIPTION
  This script validates parameters, optionally prompts for a secure admin password,
  runs a 'WhatIf' (Test-AzResourceGroupDeployment) when requested, and performs the
  deployment using New-AzResourceGroupDeployment. It writes a timestamped log file
  under .\logs and returns the deployment result.

.NOTES
  - Designed for pwsh (PowerShell 7+). Requires the Az PowerShell module.
  - Do NOT store plaintext passwords in parameter files for production. Use Key Vault.
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$false)]
    [string] $ResourceGroupName = 'Dev',

    [Parameter(Mandatory=$false)]
    [string] $Location = 'westus2',

    [Parameter(Mandatory=$false)]
    [string] $TemplateFile = (Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Path) -ChildPath '..\bicep\dev-vm.bicep'),

    [Parameter(Mandatory=$false)]
    [string] $ParameterFile = (Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Path) -ChildPath '..\parameters\dev-vm.parameters.json'),

    [Parameter(Mandatory=$false)]
    

    [Parameter(Mandatory=$false)]
    [switch] $UseExistingLogin,

    [Parameter(Mandatory=$false)]
    [switch] $ForcePasswordPrompt
)

function Install-AzModuleIfMissing {
    if (-not (Get-Module -ListAvailable -Name Az)) {
        Write-Verbose "Az module not found. Installing Az module (requires network access)."
        Install-Module -Name Az -Scope CurrentUser -Repository PSGallery -Force
    }
}

function Read-SecurePassword {
    Param(
        [string] $Prompt = 'Enter admin password (secure): '
    )
    Write-Host -NoNewline $Prompt
    $secure = Read-Host -AsSecureString
    return $secure
}

try {
    Set-StrictMode -Version Latest

    Push-Location (Split-Path -Parent $MyInvocation.MyCommand.Path)

    Install-AzModuleIfMissing

    if (-not $UseExistingLogin) {
        # Prefer non-interactive service principal in CI via environment variables
        if ($env:AZURE_CLIENT_ID -and $env:AZURE_TENANT_ID -and $env:AZURE_CLIENT_SECRET) {
            Write-Verbose 'Signing in using service principal from environment variables.'
            Connect-AzAccount -ServicePrincipal -Tenant $env:AZURE_TENANT_ID -ApplicationId $env:AZURE_CLIENT_ID -Credential (New-Object System.Management.Automation.PSCredential($env:AZURE_CLIENT_ID, (ConvertTo-SecureString $env:AZURE_CLIENT_SECRET -AsPlainText -Force))) | Out-Null
        }
        else {
            Write-Verbose 'Using interactive sign-in (Connect-AzAccount).' 
            Connect-AzAccount | Out-Null
        }
    }

    # Validate files
    $templatePath = Resolve-Path -Path $TemplateFile -ErrorAction Stop
    $paramPath = Resolve-Path -Path $ParameterFile -ErrorAction Stop

    # Optionally prompt for admin password override
    $pwOverride = $null
    if ($ForcePasswordPrompt) {
        $pwOverride = Read-SecurePassword
    }

    # Prepare parameters hashtable. If password provided, pass it as a secureString.
    $parameters = @{}
    if ($pwOverride) {
        $parameters.Add('adminPassword', $pwOverride)
    }

    # Logging
    $logsDir = Join-Path -Path (Get-Location) -ChildPath 'logs'
    if (-not (Test-Path $logsDir)) { New-Item -Path $logsDir -ItemType Directory | Out-Null }
    $timestamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
    $logFile = Join-Path $logsDir "deploy-dev-vm-$timestamp.log"

    $deployProps = @{ 
        ResourceGroupName = $ResourceGroupName
        TemplateFile = $templatePath.Path
        TemplateParameterFile = $paramPath.Path
        Mode = 'Incremental'
        ErrorAction = 'Stop'
    }

    if ($parameters.Count -gt 0) {
        $deployProps['TemplateParameterObject'] = $parameters
    }

    if ($PSBoundParameters.ContainsKey('WhatIf')) {
        Write-Host "Running Test-AzResourceGroupDeployment (WhatIf) against resource group '$ResourceGroupName'..."
        $whatifResult = Test-AzResourceGroupDeployment @deployProps -WhatIf
        $whatifResult | Out-File -FilePath $logFile -Encoding utf8
        Write-Host "WhatIf completed. Log written to $logFile"
        Exit 0
    }

    Write-Host "Starting deployment to resource group '$ResourceGroupName' using template $($templatePath.Path)"

    $deployResult = New-AzResourceGroupDeployment @deployProps 2>&1 | Tee-Object -FilePath $logFile

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Deployment failed. See log: $logFile"
        Exit 1
    }

    Write-Host "Deployment finished. Log: $logFile"

    # Output key resource ids if available
    if ($deployResult -and $deployResult.Outputs) {
        Write-Host "Deployment outputs:"
        $deployResult.Outputs | ConvertTo-Json -Depth 5 | Write-Host
    }

    Exit 0
}
catch {
    Write-Error "Error during deployment: $_"
    Exit 2
}
finally {
    Pop-Location
}
