# ADR-006: NAT Gateway now, Azure Firewall for FQDN-scoped egress later

- **Status:** Accepted
- **Date:** 2026-10-21
- **Phase:** 2 (implementation), 6 (replacement)
- **Related:** SPEC R2.2, R2.3, R6.5; flow register F5

## Context

The Twingate connector in Phase 3 initiates outbound connections to Twingate's
cloud and accepts no inbound traffic. It must not have a public IP. New Azure
VNets have no implicit outbound internet access, so the `hub-access` subnet
needs an explicit egress path before the connector can come online.

The two realistic options are:

1. **NAT Gateway + an NSG outbound allow for TCP/443 to `Internet`.**
   Cheap, simple, and sufficient for a connector that only needs to reach a
   fixed vendor service. An NSG cannot express domain names, so the rule is
   destination-wide: any HTTPS host is reachable from that subnet.
2. **Azure Firewall with application rules for Twingate's FQDNs.**
   Destination-scoped and logged, but materially more expensive and needs
   route tables, firewall policy, and a deny-log feedback loop to build the
   allow-list.

Phase 2's goal is a working, explicit egress path for the connector, not the
final inspected architecture. Phase 6 already introduces Azure Firewall for
spoke-to-spoke inspection (F1) and needs an FQDN allow-list for the connector
(F5).

## Decision

Use a **Standard NAT Gateway with one static Standard public IP**, associated
only with `hub-access`, as the interim egress path.

Add one temporary NSG rule on `hub-access-nsg`:

| Field | Value |
|---|---|
| Name | `AllowHttpsToInternet` |
| Direction / access | Outbound / Allow |
| Protocol / port | TCP / 443 |
| Source | `10.0.4.0/27` (`hub-access`) |
| Destination | `Internet` |
| Priority | 100 |
| Guard | `allow_hub_access_internet_443`, wired to `deploy_egress_nat` |

The rule is documented as accepted exception **F5** in the README and is
allow-listed in `var.nsg_allowlist_exceptions`, so the module's wildcard-rule
check keeps passing for the right reason.

The NAT Gateway public IP is an **outbound SNAT address**. It is attached to
the gateway, not to a NIC or VM, has no listener, and does not make the subnet
reachable from the internet. The `deny-public-ip-on-nic` policy therefore does
not block it; the Phase 2 apply verifies that assumption.

## Consequences

**Positive**

- The connector has egress without an inbound path or a public IP.
- Only `hub-access` gets NAT; the workload subnets stay private and unchanged.
- The exception is visible in one NSG rule, one allow-list entry, and one flow
  register row. It is easy to find and remove.
- NAT is inexpensive relative to a firewall and can stay off by default.

**Negative / accepted risks**

- `hub-access` can reach **any** host on TCP/443. That is broader than Twingate
  needs and is the explicit reason this is temporary.
- NAT provides no application-layer logging or FQDN filtering.
- The public IP is billable (roughly $35–40/month for the gateway plus IP) and
  must not be left enabled by default.

## Replacement trigger (Phase 6)

Phase 6 must:

1. Deploy Azure Firewall in `AzureFirewallSubnet` and attach a route table to
   `hub-access` with `0.0.0.0/0` next hop = firewall.
2. Remove `deploy_egress_nat` (and the NAT Gateway, public IP, and subnet
   association).
3. Remove the `AllowHttpsToInternet` rule and its `nsg_allowlist_exceptions`
   entry, and rewrite the NSG to allow only the firewall path.
4. Add firewall application rules for the Twingate FQDNs, derived from deny
   logs per R6.6.
5. Update the README accepted-exceptions table: F5 is closed, not merely
   narrowed.

## Alternatives considered

- **Public IP on the connector VM.** Rejected: violates the no-public-IP rule,
  creates an inbound surface, and is unnecessary for an outbound-initiated
  tunnel.
- **Azure default outbound access.** Rejected: retired for new VNets, gives an
  unpredictable source address, and has no explicit control to document.
- **Azure Firewall in Phase 2.** Rejected for now: the firewall is the Phase 6
  destination, and its cost and policy complexity are not justified before
  there are workloads or flow logs to validate it.
- **NAT Gateway with a public IP prefix.** Rejected: still destination-wide,
  adds cost and complexity without improving the security property.
