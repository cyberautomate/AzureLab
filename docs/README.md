# AzureLab — Hub-and-Spoke Deployment Docs

This `docs/` folder explains the staged Hub-and-Spoke network deployment implemented in this repository.

Structure:
- `design.md` — architecture and IP plan (already present)
- `deploy/` — runbooks and staged deployment instructions (coming)

Staging:
1. Stage 1: Hub (deploy `bicep/hub/main.bicep`) — creates Hub VNet, Azure Firewall, VPN Gateway (P2S)
2. Stage 2: Blue spoke (deploy `bicep/spoke-blue/main.bicep`) — creates Blue VNet, peering, route table
3. Stage 3: Red spoke (deploy `bicep/spoke-red/main.bicep`) — creates Red VNet, peering, route table

Each stage is gated by your approval.

Next: runbook and verification steps will be added under `docs/deploy/`.