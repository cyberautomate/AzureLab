# Bicep + PowerShell Best Practices (reference)

This file contains concrete patterns, minimal examples, and checklists for contributors and for Copilot to reference when generating templates or scripts.

## Contract (small)

- Inputs: Bicep module parameters (environment, location, prefix, sku, tags, optionally admin credentials via Key Vault)
- Outputs: Resource IDs and any endpoint strings required by consumers
- Error modes: validation/build errors, deployment WhatIf failures, runtime deployment errors
- Success: Bicep compiles, lint passes, Test/WhatIf shows no destructive changes (unless intended), deployment succeeds

## Bicep patterns

- Module example (module should be small and focused):
  - Inputs: `prefix`, `environment`, `location`, `tags`
  - Outputs: `id`, `name`

- main.bicep responsibilities:
  - Compose modules
  - Wire outputs
  - Validate parameter shapes early (use `allowed` values or comments)

- Secrets and Key Vault:
  - Use `existing` for Key Vault and reference secrets at deployment time, or use managed identity to grant deployment access.

## PowerShell patterns

- Script header template:
  - Param block with `[CmdletBinding()]` and `Param()` with validation
  - Help comments
  - Minimum Az module version comment

- Authentication patterns:
  - Local dev: `Connect-AzAccount`
  - CI: `Connect-AzAccount -ServicePrincipal -Tenant $env:AZ_TENANT_ID -Credential $spCredential`
  - Managed identity: `Connect-AzAccount -Identity`

## Minimal example: Bicep module (storage)

- Purpose: Provide an example that Copilot can reproduce when asked.

- Module contract (storageAccount.bicep):
  - parameters: namePrefix, location, skuName, tags
  - outputs: storageAccountId, primaryEndpoints

## Minimal example: PowerShell deploy script skeleton

- Purpose: Validate, WhatIf, then deploy with clear error handling and logging.

- Key steps in the script:
  1. Parse parameters and load parameter file
  2. Authenticate (service principal / managed identity)
  3. Build Bicep (optional pre-compile check)
  4. Run Test-AzResourceGroupDeployment / WhatIf
  5. Create/Update deployment
  6. Output results and exit with code

## Checklist for PRs that modify Bicep or scripts

- [ ] Bicep compiles (`bicep build`)
- [ ] Bicep lint passes (`bicep lint`)
- [ ] Scripts have parameter validation and non-zero exit codes on failure
- [ ] No secrets committed
- [ ] CI includes a dry-run WhatIf or Test step

## Example CI snippet (GitHub Actions)

- Use this as a reference in workflows that run on PRs:

- Steps:
  - Checkout
  - Setup Bicep (install CLI)
  - Run `bicep build` and `bicep lint`
  - Optionally run `az login` with github action and `az deployment group what-if`

## Troubleshooting tips

- If `bicep build` fails: check parameter types and module paths.
- If `WhatIf` reports unexpected deletions: inspect `mode` (Incremental vs Complete) and the parameter file.
- If deployment times out: increase client-side timeout or split deployment into smaller modules.

## Further reading

- Link to official Bicep docs, Az PowerShell docs, and security guidance (don't embed secrets here).
