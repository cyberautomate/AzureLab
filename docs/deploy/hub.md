# Stage 1 — Hub deployment runbook

This runbook describes how to build and validate the Hub deployment (stage 1). The Hub creates:
- Hub VNet and subnets (VM subnets, container delegated subnet, AzureFirewallSubnet, GatewaySubnet)
- Azure Firewall (Basic SKU) with public IP
- Virtual Network Gateway for P2S (Azure AD authentication)
- Hub route table containing a 0.0.0.0/0 route to the firewall private IP

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

2. Build the Hub template locally:

```powershell
bicep build bicep/hub/main.bicep
```

3. Run a WhatIf against the Hub resource group (replace values):

```powershell
az deployment group what-if --resource-group <hub-rg> --template-file bicep/hub/main.bicep --parameters @bicep/parameters/hub.parameters.json
```

4. When satisfied, run a deployment:

```powershell
az deployment group create --resource-group <hub-rg> --template-file bicep/hub/main.bicep --parameters @bicep/parameters/hub.parameters.json
```

Post-deploy validation
- Verify `AzureFirewall` resource is present in Hub RG and has a public IP.
- Verify `GatewaySubnet` exists and virtual network gateway is ProvisioningState Succeeded.
- Confirm hub route table contains a default route to the firewall private IP.

Notes
- P2S authentication: The Bicep template will default to certificate-based unless you pass parameters to enable Azure AD. If you prefer Azure AD P2S, update the parameters before deployment.
