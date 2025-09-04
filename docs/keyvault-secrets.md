# Using Key Vault for AAD IDs & Secrets

This project now supports deploying a Key Vault to hold environment-specific secrets (like Azure AD object IDs, client IDs, or other sensitive values) instead of hardcoding them in Bicep templates or parameter files.

## 1. Deployment Flow (Two-Step)

1. Deploy the Key Vault only:

```powershell
pwsh ./scripts/deploy-keyvault.ps1 -ResourceGroupName my-rg -Location eastus -ParameterFile ./parameters/keyvault.dev.parameters.json
```

1. Populate the Key Vault with required secrets (one-time or whenever values rotate):

- Example secret names: `aadAppClientId`, `aadGroupObjectId`, `platformAdminObjectId`.

1. Deploy the rest of the infrastructure (which now omits Key Vault):

```powershell
pwsh ./scripts/deploy.ps1 -ResourceGroupName my-rg -Location eastus -ParameterFile ./parameters/dev.parameters.json -KeyVaultName myproj-dev-kv -SecretNames aadAppClientId,platformAdminObjectId
```

1. The infra deployment script resolves listed secrets and passes them as parameters when templates define matching parameter names.

## 2. Adding New Secrets
Decide on a parameter name in Bicep (e.g. `aadAppClientId`). Create a secret in the Key Vault with the SAME name for easy mapping:
```powershell
Set-AzKeyVaultSecret -VaultName <kv-name> -Name aadAppClientId -SecretValue (ConvertTo-SecureString '<guid>' -AsPlainText -Force)
```

## 3. Running Infrastructure Deployment with Secrets
After the Key Vault is deployed and populated:
```powershell
pwsh ./scripts/deploy.ps1 -ResourceGroupName my-rg -Location eastus -ParameterFile ./parameters/dev.parameters.json -KeyVaultName myproj-dev-kv -SecretNames aadAppClientId,platformAdminObjectId -ShowResolvedParameters
```
Any secret listed in `-SecretNames` is retrieved and merged into the parameter object, overriding existing parameter file values with the same name.

## 4. Parameter File Guidance
Parameter files should omit sensitive values or set placeholders, e.g.:
```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "namePrefix": { "value": "myproj" },
    "environment": { "value": "dev" },
    "aadAppClientId": { "value": "__fromKeyVault__" }
  }
}
```

## 5. RBAC vs Access Policies
The Key Vault module defaults to `enableRbacAuthorization: true`. Grant your deployment principal (SPN or managed identity) suitable roles, e.g.:
- Key Vault Secrets User (read)
- Key Vault Administrator (manage) – only if needed

## 6. Rotating & Updating Secrets
Update a secret value with a new version. Redeploy: the script fetches the latest (current) version automatically.

## 7. Extending
If a module needs a new secret:

1. Add a `param` in the relevant Bicep module or main template.
1. Reference that parameter where needed.
1. Add the secret to Key Vault and include its name in `-SecretNames`.

## 8. Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| Secret not found | Typo or missing secret | Run `Get-AzKeyVaultSecret -VaultName <kv> -Name <name>` |
| Access denied | Missing Key Vault RBAC | Assign Key Vault Secrets User role |
| Parameter not overriding | Secret name mismatch | Ensure secret name == parameter name |

## 9. Security Notes

- Avoid committing real GUIDs or object IDs if they are sensitive or subject to change.
- Use least privilege for the deployment identity.
- Consider private endpoints and disabled public network access for production vaults.

---
Last updated: 2025-09-04
