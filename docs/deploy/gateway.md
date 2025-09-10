# VPN Gateway Deployment (Standalone)

This template (`bicep/hub/gateway.bicep`) deploys only the VPN Gateway and its public IP, separated from core hub resources.

## When to Use

Use after the core hub (VNet, firewall, route table) is successfully deployed using `scripts/deploy-hub.ps1`. This separation prevents long‑running or failed gateway provisioning from blocking the rest of the hub infrastructure.

## Parameters (gateway.bicep)

| Name | Description | Default |
|------|-------------|---------|
| location | Resource group location | rg location |
| vnetName | Hub virtual network name | hub-vnet |
| gatewayName | VPN gateway resource name | hub-vpngw |
| publicIpName | Public IP for gateway | hub-vpngw-pip |
| gatewaySku | VPN GW SKU | VpnGw1 |
| vpnP2S | P2S config (AAD) | object |

## Deployment Scripts

### 1. Core Hub (without gateway)

```powershell
./scripts/deploy-hub.ps1 -ResourceGroupName hub -Location westus2 -FirewallTier Basic -AutoDeleteConflicts
```

Options:

- `-FirewallTier Basic|Standard|Premium`
- `-AutoDeleteConflicts` automatically removes an incompatible existing firewall
- `-WhatIf` previews changes only

### 2. VPN Gateway

```powershell
./scripts/deploy-gateway.ps1 -ResourceGroupName hub -KeyVaultName <kv-name> -AutoDeleteConflicts
```

Options:

- `-GatewaySku VpnGw1|VpnGw2|...`
- `-AutoDeleteConflicts` removes an existing conflicting gateway + public IP
- `-WhatIf` preview mode

## Key Vault Secrets

The gateway script expects these secrets in the specified Key Vault:

- `aadTenantId`
- `aadAudience`

Ensure they are non-empty. Populate via `scripts/set-keyvault-secrets.ps1` if needed.

## Pre-Flight Conflict Handling

Both scripts detect existing immutable appliance configuration (firewall tier or gateway SKU). If mismatched and `-AutoDeleteConflicts` is supplied, the resource (and its public IP) is deleted and recreated. Without the switch the deployment stops with a clear error.

## Management Subnet (Firewall Basic)

When `FirewallTier` is `Basic`, the hub template creates:

- `AzureFirewallSubnet` (10.0.3.0/26)
- `AzureFirewallManagementSubnet` (10.0.3.128/26)

If you switch tiers later, remove the existing firewall first or redeploy with `-AutoDeleteConflicts`.

## Typical Sequence

1. Deploy Key Vault + secrets.
2. Run `deploy-hub.ps1` (firewall Basic or Standard).
3. Run `deploy-gateway.ps1` (injects AAD P2S values).
4. Deploy spokes referencing hub outputs as needed.

## Troubleshooting

- Conflict errors: Re-run with the appropriate `-AutoDeleteConflicts` flag.
- Missing secrets: Ensure RBAC role (Key Vault Secrets User/Officer) on the Key Vault.
- Long gateway provisioning: Avoid repeated redeploy; inspect provisioning state in portal or via `Get-AzResource`.

## Cleanup

To remove only the gateway:

```powershell
Remove-AzResource -ResourceGroupName hub -ResourceType Microsoft.Network/virtualNetworkGateways -Name hub-vpngw -Force
Remove-AzResource -ResourceGroupName hub -ResourceType Microsoft.Network/publicIPAddresses -Name hub-vpngw-pip -Force
```

To remove firewall (Basic/Standard):

```powershell
Remove-AzResource -ResourceGroupName hub -ResourceType Microsoft.Network/azureFirewalls -Name hub-firewall -Force
Remove-AzResource -ResourceGroupName hub -ResourceType Microsoft.Network/publicIPAddresses -Name hub-firewall-pip -Force
```

## End-to-End Example

End-to-end (assuming resource group `hub` and spokes `spoke-blue`, `spoke-red` already exist):

```powershell
# 1. Key Vault (if not already)
./scripts/deploy-keyvault.ps1 -ResourceGroupName hub -Location westus2 -ParameterFile ./parameters/keyvault.dev.parameters.json

# 2. Set P2S AAD secrets
./scripts/set-keyvault-secrets.ps1 -KeyVaultName <kv-name> -TenantId <tenant-guid> -Audience <app-id-or-resource-uri>

# 3. Deploy Hub (firewall Basic)
./scripts/deploy-hub.ps1 -ResourceGroupName hub -Location westus2 -FirewallTier Basic

# 4. Deploy VPN Gateway (pulls secrets)
./scripts/deploy-gateway.ps1 -ResourceGroupName hub -KeyVaultName <kv-name>

# 5. Deploy spokes
az deployment group create --resource-group spoke-blue --template-file bicep/spoke-blue/main.bicep
az deployment group create --resource-group spoke-red  --template-file bicep/spoke-red/main.bicep

# 6. (Optional) Peer spokes to hub (example blue->hub)
az network vnet peering create --resource-group hub --vnet-name hub-vnet --name hub-to-blue --remote-vnet /subscriptions/<subId>/resourceGroups/spoke-blue/providers/Microsoft.Network/virtualNetworks/blue-vnet --allow-vnet-access
az network vnet peering create --resource-group spoke-blue --vnet-name blue-vnet --name blue-to-hub --remote-vnet /subscriptions/<subId>/resourceGroups/hub/providers/Microsoft.Network/virtualNetworks/hub-vnet --allow-vnet-access
```

Hub outputs available after deployment (from `bicep/hub/main.bicep`):

- `hubVnetId`
- `firewallId`
- `firewallPublicIp`

Use these outputs for automation (e.g., tagging, diagnostics, additional route table associations) or to validate firewall IP referenced in spoke route tables if you later add custom UDRs in spokes.

## Firewall P2S Allow Rule

The hub firewall template (`bicep/hub/main.bicep`) now passes a default `p2sAddressPool` (`172.16.201.0/24`) to `azureFirewall.bicep`. If present, the module adds a simple network rule collection named `allow-p2s` permitting any protocol/port from the P2S client pool to any destination. Tighten this later by editing `p2sAddressPool` or the module logic. Set it to an empty string to remove the automatic rule.
