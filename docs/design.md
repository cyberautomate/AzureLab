# Hub-and-Spoke Lab Design

## Overview
This repository will implement a hub-and-spoke network topology in Azure with a centralized internet egress point managed from the Hub resource group using Azure Firewall (Basic SKU).

Goals:
- Centralize internet access in the Hub with Azure Firewall (Basic SKU).
- Ensure spokes have no public IP addresses.
- Provide Point-to-Site (P2S) VPN to the Hub via an Azure Virtual Network Gateway.
- Use contiguous, simple IP addressing under a single /16 for clarity and future expansion.
- Deploy in three staged deployments: Hub (stage 1), Blue spoke (stage 2), Red spoke (stage 3).
- Provide extensive documentation in `/docs` so any GitHub visitor can understand what's happening step-by-step.

## High-level architecture
- Single management Hub resource group (you indicated hub resource group is already created).
- Hub VNet hosts:
  - 2 × /24 VM subnets
  - 1 × /24 Container subnet (delegation enabled)
  - `AzureFirewallSubnet` (managed firewall)
  - `GatewaySubnet` (for VPN Gateway)
- Blue and Red spokes: each with 2 × /24 VM subnets and 1 × /24 Container delegated subnet.
- Hub will contain an Azure Firewall (Basic SKU) with a public IP and private IP on `AzureFirewallSubnet`.
- User Defined Routes (UDRs) in each spoke will send internet-bound traffic (0.0.0.0/0) to the Azure Firewall private IP using nextHopType `VirtualAppliance`.
- VNets will be peered (Hub ⟷ Spoke). Peering will be configured to allow forwarded traffic and gateway transit from spoke to hub where needed.

## IP addressing plan (contiguous and simple)
We allocate a single /16 for the lab and slice it into contiguous /22 and /24 blocks to keep addresses simple and future-proof.

Base prefix: 10.0.0.0/16

Hub VNet: 10.0.0.0/22 (covers 10.0.0.0 - 10.0.3.255)
- Hub-VM-Subnet-1: 10.0.0.0/24
- Hub-VM-Subnet-2: 10.0.1.0/24
- Hub-Container-Subnet (delegation): 10.0.2.0/24
- Hub-Infra-Subnet (firewall + gateway host space): 10.0.3.0/24
  - AzureFirewallSubnet (example carve): 10.0.3.0/26
  - GatewaySubnet (example carve): 10.0.3.64/27

Blue Spoke VNet: 10.0.4.0/22 (covers 10.0.4.0 - 10.0.7.255)
- Blue-VM-Subnet-1: 10.0.4.0/24
- Blue-VM-Subnet-2: 10.0.5.0/24
- Blue-Container-Subnet (delegation): 10.0.6.0/24

Red Spoke VNet: 10.0.8.0/22 (covers 10.0.8.0 - 10.0.11.255)
- Red-VM-Subnet-1: 10.0.8.0/24
- Red-VM-Subnet-2: 10.0.9.0/24
- Red-Container-Subnet (delegation): 10.0.10.0/24

Notes:
- The Hub infra address space reserves a full /24 so we can allocate subranges (Firewall, Gateway, load balancers, etc.) without collision. Azure requires the subnet name `AzureFirewallSubnet`. GatewaySubnet must exist and be named exactly `GatewaySubnet`.
- All subnets are contiguous and non-overlapping. The /16 gives room for expansion and additional spokes.

## Centralized Internet Egress - Azure Firewall (Basic SKU)
Rationale for Azure Firewall Basic SKU:
- Centralized filtering and outbound control for spokes.
- Integrates with route tables (UDRs) using VirtualAppliance next hop.
- Good balance for lab/testing — Basic SKU is less expensive than Standard and supports essential features needed here.

Design notes:
- The Azure Firewall will be deployed in `AzureFirewallSubnet` inside the Hub and will require a public IP.
- Spoke route tables will include a 0.0.0.0/0 route that points to the firewall's private IP as a `VirtualAppliance` next hop.
- Firewall DNAT/SNAT and rules will be authored from the Hub to permit outbound and any required inbound management traffic (VPN, jumpboxes if needed). For inbound access to resources in spokes, use private peering + firewall rules or use jumpbox in Hub (no public IPs in spokes).

## VPN Gateway (Point-to-Site)
- A Virtual Network Gateway will be deployed in the Hub `GatewaySubnet` to provide P2S connectivity.
- P2S will be configured to allow on-premises access. Authentication options: Azure AD, RADIUS, or certificate-based. We'll parameterize this in Bicep for your choice.

## Security & no-public-IP policy for spokes
- Spoke deployments will not create Public IP resources. We'll add an Azure Policy recommendation in the docs to prevent accidental Public IPs in spoke resource groups.
- Default NSGs will be created for management subnets; explicit rules will be documented and configurable via parameters.

## Route table & peering behavior
- Each spoke will have a route table applied that sends 0.0.0.0/0 -> Azure Firewall private IP (VirtualAppliance).
- VNet peering will enable forwarded traffic from the spoke to the Hub firewall. Peering will be configured with "Allow forwarded traffic" and "Use remote gateways" (as needed for gateway transit).

## Staged deployment plan
- Stage 1 (Hub): deploy Hub VNet, `AzureFirewallSubnet`, Azure Firewall Basic SKU with public IP, `GatewaySubnet` and VPN Gateway, routeTables templates (not yet assigned to spokes), and outputs for firewall private IP and vnetId.
- Stage 2 (Blue): deploy Blue VNet and subnets + routeTable that points to firewall private IP; create peering to Hub. No resources with public IPs.
- Stage 3 (Red): same as Blue.

Each stage will be gated - you will test and give approval before moving to the next stage.

## Acceptance criteria (what "done" looks like for each stage)
Stage 1 (Hub):
- Hub VNet and subnets exist with expected CIDRs.
- Azure Firewall Basic deployed with public IP and reachable private IP in `AzureFirewallSubnet`.
- GatewaySubnet exists and VPN Gateway is provisioned (WhatIf / test configuration available to validate P2S).
- Bicep `build` succeeds and outputs include firewall private IP and vnetId.

Stage 2 (Blue) & Stage 3 (Red):
- Spoke VNets and subnets exist with expected CIDRs.
- VNet peering to Hub exists and allows forwarded traffic.
- Route table in spoke routes 0.0.0.0/0 to Azure Firewall private IP (via VirtualAppliance). Validate that a test VM in spoke has no public IP and can reach the Internet via Firewall.

## Files to be produced by the implementation
- `bicep/modules/vnet.bicep` - reusable VNet + subnet module (supports delegation)
- `bicep/modules/vnetPeering.bicep` - create peering between hub and spoke
- `bicep/modules/azureFirewall.bicep` - Azure Firewall Basic SKU module
- `bicep/modules/vpnGateway.bicep` - VPN Gateway for P2S
- `bicep/hub/main.bicep` - Hub deployment (stage 1)
- `bicep/spoke-blue/main.bicep` - Blue spoke (stage 2)
- `bicep/spoke-red/main.bicep` - Red spoke (stage 3)
- `bicep/ip-plan.json` - machine-readable IP plan (created alongside this document)
- `docs/` - this design and subsequent runbooks and how-tos
- `scripts/deploy.ps1` - staged deploy script

## Next steps after reviewing this doc
- Confirm the Azure Firewall Basic SKU decision (you already approved this in the last message). I'll proceed to create the `bicep/ip-plan.json` (done) and then implement the `bicep/modules/vnet.bicep` and `bicep/hub/main.bicep` skeletons. We will not run any deployments until you explicitly authorize Stage 1 deployment.

---

If you'd like, I can produce a simple ASCII diagram here or generate a PNG and add it to `/docs`.
