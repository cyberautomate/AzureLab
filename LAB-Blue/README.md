# LAB-Blue spoke VNet

This folder deploys a spoke virtual network in the LAB-Blue subscription and peers it to the hub VNet.

Files:
- `main.bicep` - Bicep template to create VNet, subnet, route table and peering (spoke-side).
- `dev.parameters.json` - example parameters for dev environment.

Usage:
1. Update `dev.parameters.json` with `hubSubscriptionId` and `hubFirewallPrivateIp`.
2. From repo root run the `deploy-LAB-Blue.ps1` script.

The deployment script queries existing VNets to ensure the address space you provide does not overlap with existing VNets across subscriptions.
