# My Azure Lab

All infrastructure is defined with Bicep and deployed via modular PowerShell scripts.

## Documentation

- Hub deployment runbook: `docs/deploy/hub.md`
- VPN Gateway deployment runbook: `docs/deploy/gateway.md`
- Key Vault secrets guidance: `docs/keyvault-secrets.md`

## Deployment Order (End-to-End)

1. Create resource groups (HUB, SPOKE-BLUE, SPOKE-RED) and optionally deploy the subscription policy.
2. Deploy Key Vault & populate AAD P2S secrets (`aadTenantId`, `aadAudience`).
3. Deploy Hub (firewall + route table, no gateway yet).
4. Deploy VPN Gateway (injects AAD P2S values from Key Vault).
5. Deploy spokes (blue/red) and set up VNet peerings.

## Quick Commands

Deploy the Key Vault:

```powershell
./scripts/deploy-keyvault.ps1 -ResourceGroupName HUB -Location westus2 -ParameterFile ./parameters/keyvault.dev.parameters.json -ShowParameters
```

Set the Key Vault secrets (replace values):

```powershell
./scripts/set-keyvault-secrets.ps1 -KeyVaultName <kv-name> -TenantId <aad-tenant-guid> -Audience <vpn-app-id-or-reply-url>
```

Deploy Hub (Basic firewall tier default):

```powershell
./scripts/deploy-hub.ps1 -ResourceGroupName HUB -Location westus2 -FirewallTier Basic
```

Deploy VPN Gateway:

```powershell
./scripts/deploy-gateway.ps1 -ResourceGroupName HUB -KeyVaultName <kv-name>
```

Deploy Spoke (example blue):

```powershell
az deployment group create --resource-group SPOKE-BLUE --template-file bicep/spoke-blue/main.bicep
```

Or include the Blue spoke VNet during a composite deployment of the root template by setting the new boolean parameter:

```powershell
az deployment group create --resource-group <rg> --template-file bicep/main.bicep --parameters namePrefix=lab environment=dev deployBlueVnet=true
```

PowerShell script alternative for the blue spoke only:
Deploy Spoke (example red):

```powershell
az deployment group create --resource-group SPOKE-RED --template-file bicep/spoke-red/main.bicep
```

Or via root template together with blue:

```powershell
az deployment group create --resource-group <rg> --template-file bicep/main.bicep --parameters namePrefix=lab environment=dev deployBlueVnet=true deployRedVnet=true
```

PowerShell script alternative for the red spoke only:

```powershell
./scripts/deploy-spoke-red.ps1 -ResourceGroupName Red -Location westus2
```

```powershell
./scripts/deploy-spoke-blue.ps1 -ResourceGroupName Blue -Location westus2
```

## Learning Bicep

If you're new to Bicep, start here: <https://learn.microsoft.com/azure/azure-resource-manager/bicep/>
