# Contributing

Thanks for contributing to this Azure IaC repository. The repository includes guidance for GitHub Copilot and contributors to create and modify Bicep templates and PowerShell deployment scripts.

Please read these files first:

- `.github/copilot-instructions.md` — high-level guidance and examples used by Copilot
- `.github/bicep-powershell-best-practices.md` — concrete patterns, examples, and PR checklist

Quick local validation steps:

1. Install Bicep CLI and Az PowerShell module.
2. Build Bicep: `bicep build bicep/main.bicep --outfile build/main.json`
3. Lint Bicep (if you have bicep linter installed): `bicep lint bicep/main.bicep`
4. Validate deployment with Test/WhatIf (see `scripts/deploy.ps1` for a scripted flow).

When opening a PR that touches Bicep or deployment scripts, ensure the checklist in `.github/bicep-powershell-best-practices.md` is satisfied.
