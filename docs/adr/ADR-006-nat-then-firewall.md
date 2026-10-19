# ADR-006: NAT Gateway as interim egress, Azure Firewall as the target

- **Status:** Accepted
- **Date:** 2026-10-19
- **Deciders:** Akshay
- **Related:** SPEC R2.1–R2.4, R6.1–R6.8; roadmap Phases 2 and 6; flow F5

## Context

A new VNet has no implicit outbound internet access. The Twingate connector in
`hub-access` must reach the Twingate cloud on 443, so it needs an egress path.

Two options dominate:

- **NAT Gateway:** cheap (roughly $35–40/month plus data), simple, and gives a
  stable public IP. It does not inspect or restrict destinations.
- **Azure Firewall:** roughly $300/month if left on, but it provides FQDN
  allow-listing and a central inspection point.

The project needs a working connector in Phase 3 and a real inspection story in
Phase 6. Paying for the firewall before there are workloads and logs would consume
the budget before there is anything to inspect.

## Decision

Use a **NAT Gateway** on `hub-access` in Phase 2, behind `deploy_egress_nat`
(default `false`), with a temporary outbound NSG allowance of TCP/443 to the
`Internet` service tag.

Replace it in Phase 6 with **Azure Firewall Basic** plus an FQDN allow-list derived
from the firewall's own logs, behind `deploy_firewall`. The temporary
`Internet:443` rule is removed in Phase 6.

Only `hub-access` gets NAT. No other subnet gets a broad egress path.

## Consequences

### Positive

- Phase 3 can test the connector for tens of dollars, not hundreds.
- The NAT public IP is a stable value for allow-listing and evidence.
- The Phase 6 migration has a clear success criterion: the connector stays Online
  with the temporary rule removed.

### Negative / accepted costs

- Phases 2–5 accept broad HTTPS egress from `hub-access` (F5). A compromised
  connector can reach any HTTPS destination; this is documented and time-boxed.
- The NAT Gateway and public IP must be destroyed with `make down`.
- Phase 6 is a real migration: route tables, firewall policy, and an FQDN list
  learned from logs, not guessed.

## Alternatives considered

| Alternative | Why not |
|---|---|
| Firewall from Phase 2 | Expensive before there are workloads or logs; the FQDN list would be guesswork. |
| No egress until Phase 6 | The connector cannot come online, so Phase 3 cannot be tested. |
| NAT Gateway as the permanent design | No inspection or destination control; F5 would remain broad forever. |
| Egress through a self-managed NVA | More operational work than the firewall for less policy integration. |

## Review

Phase 6. The decision is complete when `deploy_egress_nat = false`,
`deploy_firewall = true`, the connector is Online, and the `Internet:443` rule no
longer exists.
