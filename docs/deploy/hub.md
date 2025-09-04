# Stage 1 — Hub deployment runbook

This runbook describes how to build and validate the Hub deployment (stage 1). The Hub (core) now creates ONLY:

- Hub VNet and subnets (VM subnets, container delegated subnet, AzureFirewallSubnet, AzureFirewallManagementSubnet when Basic tier, GatewaySubnet)
- Azure Firewall (tier selectable: Basic | Standard | Premium) with public IP
- Hub route table containing a 0.0.0.0/0 route to the firewall private IP

The Virtual Network Gateway has been split into a separate deployment stage to isolate long-running provisioning. After completing this runbook proceed to the VPN Gateway runbook: `docs/deploy/gateway.md`.

Pre-reqs

- You have Bicep and Azure CLI installed and logged in.
- You have an Azure subscription and a Hub resource group already created.

Steps

1. (Optional) Deploy the subscription-scoped policy that denies public IPs (DoNotEnforce) so GitHub/onboarding users are aware.

   Run from repository root:

```powershell
# Deploy the subscription-scoped policy (DoNotEnforce by default)
az deployment sub create --location <location> --template-file bicep/policy/deploy-subscription.bicep
```

1. Build the Hub template locally:

```powershell
bicep build bicep/hub/main.bicep
```

1. Run a WhatIf against the Hub resource group (replace values). You can optionally override the firewall tier (default Basic):

```powershell
az deployment group what-if --resource-group <hub-rg> --template-file bicep/hub/main.bicep --parameters @bicep/parameters/hub.parameters.json
```

1. When satisfied, run a deployment (example with Premium tier):

```powershell
az deployment group create --resource-group <hub-rg> --template-file bicep/hub/main.bicep --parameters @bicep/parameters/hub.parameters.json
```

Post-deploy validation

- Verify `AzureFirewall` resource is present in Hub RG and has a public IP.
- Confirm hub route table contains a default route to the firewall private IP.

Next Stage

- Deploy the VPN Gateway using `scripts/deploy-gateway.ps1` (see `docs/deploy/gateway.md`). This will inject Azure AD P2S settings from Key Vault secrets `aadTenantId` and `aadAudience`.

Notes

- Gateway moved: The Virtual Network Gateway is no longer in this template. Use the separate gateway deployment after the hub is healthy.
- Firewall tier changes: Re-run hub deployment with `-AutoDeleteConflicts` (script) or manually delete the firewall if changing tier on an existing deployment.
