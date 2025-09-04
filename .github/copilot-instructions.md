```instructions
# GitHub Copilot Instructions for Azure Infrastructure Deployment

## 🧱 Project Overview

This repository contains infrastructure-as-code (IaC) for deploying Azure resources using **Bicep** templates and managing deployments via **PowerShell** scripts. The goal is to enable repeatable, modular, secure, and environment-specific deployments across dev, test, and production environments.

---

## 🧠 Copilot Guidance (what Copilot should suggest)

This section tells Copilot how to generate useful, production-ready code for contributors working in this repo.

### 🔹 Technologies to prefer
- Bicep (latest stable CLI) for resource templates
- PowerShell (pwsh) scripts using the `Az` PowerShell module for deployments and automation
- Azure CLI where helpful for local testing or CI steps
- GitHub Actions for CI/CD automation (use `azure/login` and secrets)

### 🔹 Recommended repo layout
- `bicep/`: modular Bicep templates and a `main.bicep` that composes modules
- `modules/` (inside `bicep/`): small reusable Bicep modules (vnet, subnet, storage, appsvc)
- `parameters/`: parameter JSON files per environment (e.g., `dev.parameters.json`)
- `scripts/`: PowerShell scripts for deploy/validate/teardown and helper scripts
- `.github/workflows/`: CI/CD workflows that run lint/build/test and deploy to non-prod environments

### 🔹 Naming & tagging conventions
- Resource names: lowercase, hyphen-separated (e.g., `${env}-rg` or `myproj-${env}-vnet`)
- Parameter names: consistent across modules (`environment`, `location`, `prefix`, `tags`)
- Always include a `tags` object for billing/owner/stack information

---

## ✅ Bicep best practices (what to generate / recommend)

- Use modules for repeated constructs. Keep modules small (single responsibility): VNet, Subnet, StorageAccount, AppService, KeyVault.
- Parameterize everything that varies between environments: `environment`, `location`, `sku`, `tags`, `admin` values.
- Use typed parameters in Bicep (string, int, bool, object, array, secureString) and provide sensible defaults where appropriate.
- Avoid hard-coded values; prefer parameters and lookups.
- Use `existing` to reference resources that live outside the module (e.g., an existing Log Analytics workspace or Key Vault).
- Emit useful outputs from modules (resource ids, connection strings, principal ids) and surface them in `main.bicep` outputs.
- Keep stateful resources (Storage, KeyVault) name-deterministic using a prefix + hash if needed to meet Azure naming rules.
- Validate with the Bicep toolchain: `bicep build`, `bicep lint` and `bicep build --outfile` as part of PR checks.
- Prefer deployment-time references for secrets: use Key Vault references and managed identity rather than plaintext secrets in parameter files.
- Use `scope` for subscription/resource group/management group deployments when the template targets different scopes.
- Use conditions and loops sparingly and clearly; prefer explicit resources over complex dynamic templates when readability suffers.

Quick commands to recommend in examples:
- bicep build bicep/main.bicep --outfile build/main.json
- bicep lint bicep/main.bicep
- az deployment group create --resource-group my-rg --template-file bicep/main.bicep --parameters @parameters/dev.parameters.json
- az deployment sub create --location eastus --template-file bicep/subscription.bicep --parameters @parameters/sub.parameters.json

---

## ✅ PowerShell best practices (what to generate / recommend)

- Use `pwsh` (PowerShell Core) scripts for cross-platform compatibility.
- Require the `Az` PowerShell module pinned to a minimum version in script comments and CI.
- Favor parameterized scripts with named parameters and helpful validation attributes (ValidateNotNullOrEmpty, ValidateSet).
- Use `Connect-AzAccount -Identity` or service principal login in CI. Avoid interactive logins in automation.
- Use `Test-AzResourceGroupDeployment` or `WhatIf` before applying changes to production.
- Provide robust error handling using try/catch and meaningful exit codes. Return non-zero on failure so CI can fail fast.
- Use `Start-Transcript` / `Stop-Transcript` for capturing verbose logs during runs, or write verbose output to a log file.
- Keep idempotency in mind: prefer `Incremental` mode for iterative work, and only use `Complete` when you intend to delete resources not in the template.

Example snippet patterns to generate or include in scripts:
- Parameter block with validation
- Connect-AzAccount with service principal using secrets stored in environment variables
- Run `Test-AzResourceGroupDeployment` then `New-AzResourceGroupDeployment` if tests pass
- Proper try/catch around the deployment calls with detailed logging

---

## ✅ CI/CD and PR guidance

- Each PR that touches Bicep should run (via GitHub Actions):
  - bicep build (detect compile errors)
  - bicep lint (style and best-practice checks)
  - a dry-run (WhatIf) deployment against a disposable or staging subscription/resource-group
- Store service principal credentials in `AZURE_CREDENTIALS` (GitHub secret) or use `azure/login` action.
- Use `bicep build` output as the artifact to deploy in release jobs to ensure the deployed JSON is the validated artifact.

---

## ✅ Security & secrets

- Never store secrets or credentials in repo files. Use Key Vault and reference secrets at deployment time.
- Use managed identities for resources that need to read secrets from Key Vault.
- When CI needs to deploy, use a minimal-permission service principal or a short-lived managed identity.

---

## ✅ What Copilot should not do

- Don't generate plaintext secrets or hard-coded credentials in templates or scripts.
- Don't assume an interactive Azure login in automation scenarios; prefer service principal or managed identity patterns.

---

## ✅ Example prompts for contributors (helpful to show in PR templates)
- "Generate a small Bicep module for an Azure Storage account with tags and a SKU parameter."
- "Create a `deploy.ps1` PowerShell script that validates and deploys `bicep/main.bicep` to a resource group using a parameter file and service-principal auth." 
- "Add a GitHub Action to lint and build Bicep files on PRs to main."

``` # GitHub Copilot Instructions for Azure Infrastructure Deployment

## 🧱 Project Overview

This repository contains infrastructure-as-code (IaC) for deploying Azure resources using **Bicep** templates and managing deployments via **PowerShell** scripts. The goal is to enable repeatable, modular, and environment-specific deployments across dev, test, and production environments.

## 🧠 Copilot Guidance

### 🔹 Technologies Used
- **Bicep** for defining Azure infrastructure
- **PowerShell** for deployment automation
- **Azure CLI** and **Az PowerShell Module**
- **GitHub Actions** for CI/CD (optional)

### 🔹 Folder Structure
- `bicep/`: Contains main and modular Bicep templates
- `scripts/`: PowerShell scripts for deployment, validation, and teardown
- `parameters/`: JSON parameter files for different environments
- `.github/workflows/`: CI/CD pipelines (if applicable)

### 🔹 Naming Conventions
- Use lowercase, hyphenated names for resources (e.g., `myproject-vnet`)
- Prefix resource names with environment (e.g., `dev-storage`, `prod-appsvc`)
- Use consistent parameter names across Bicep modules

### 🔹 Bicep Best Practices
- Use modules for reusable components (e.g., VNet, Storage, App Service)
- Parameterize environment, location, and SKU
- Include `tags` for all resources
- Use `existing` keyword for referencing existing resources
- Validate templates using `bicep build` and `bicep lint`

### 🔹 PowerShell Best Practices
- Use `Az` module cmdlets (e.g., `New-AzResourceGroupDeployment`)
- Include logging and error handling
- Use parameterized scripts for environment-specific deployments
- Validate deployments using `Test-AzResourceGroupDeployment`

### 🔹 Copilot Suggestions
- Suggest Bicep modules with parameters and outputs
- Generate PowerShell scripts for deploying Bicep templates
- Provide inline comments and documentation
- Recommend reusable patterns and modular code

## ✅ Example Prompts

- "Create a Bicep module for an Azure App Service with configurable SKU and tags."
- "Write a PowerShell script to deploy a Bicep template using a parameter file."
- "Generate a validation script for a Bicep deployment using Test-AzResourceGroupDeployment."