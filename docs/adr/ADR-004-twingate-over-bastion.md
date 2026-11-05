# ADR-004: Twingate Identity-Based ZTNA Instead of Azure Bastion

- **Status:** Accepted
- **Date:** 2026-11-05
- **Phase:** 3
- **Related:** SPEC R3.9, ADR-003

## Context

Private workloads across the hub and spoke virtual networks have no public IP addresses and enforce default-deny NSG rules (`priority 4096`). To manage and verify these workloads, operators need secure remote access without puncturing default-deny or exposing SSH/RDP ports to the public internet.

The options evaluated:
1. **Azure Bastion (PaaS Jump Host):**
   A managed jump-host service deployed in a dedicated `AzureBastionSubnet`. Users connect via the Azure Portal or Azure CLI tunneled over HTTPS.
2. **Twingate Zero Trust Network Access (ZTNA):**
   A software-defined zero-trust overlay. A lightweight connector VM runs inside the hub network, maintaining an outbound-only connection to Twingate's relay infrastructure. Users install the Twingate client, authenticate through an Identity Provider (Entra ID), and access allowed resources based strictly on group membership.

## Decision

Use **Twingate ZTNA** for all remote management access. Do not deploy Azure Bastion (neither permanently nor behind an active default flag).

If Twingate is unavailable or the connector is offline during testing, emergency maintenance and automated verification will use Azure Run Command (`az vm run-command invoke`), which operates over the Azure control plane rather than in-guest network ingress.

## Rationale

1. **True Zero Trust Demonstration:**
   Azure Bastion is network-centric: any user authorized on the Bastion resource can reach network endpoints across peered VNets if NSGs allow it. Twingate provides granular, resource-level least privilege: permissions are bound to identity and group claims (e.g. `zt-developers` can SSH to workloads, whereas `zt-auditors` can only reach storage blob endpoints).
2. **Cost Efficiency:**
   Azure Bastion Developer/Basic SKU incurs ~$140/month minimum base cost continuously while provisioned. Twingate's Starter plan is free (supporting up to 5 users, 50 resources, and 2 connectors), which fits within student and dev budgets.
3. **No Inbound Open Ports:**
   Bastion requires an ingress public IP and open port 443 on the Bastion subnet. Twingate connectors establish outbound-only TLS tunnels through the NAT Gateway, maintaining a 100% closed perimeter for inbound traffic.

## Consequences

### Positive
- Zero inbound ports open to the public internet across the entire network architecture.
- Fine-grained, identity-aware access control demonstrating group policy separation (e.g. developer vs. auditor roles).
- Significant cost savings compared to managed Azure Bastion.

### Negative / Accepted Risks
- Requires client software installation on operator machines.
- Dependent on third-party SaaS availability (Twingate relay/controller).
- Free tier lacks automated SCIM directory synchronization; groups are managed as custom groups directly or via Terraform.
