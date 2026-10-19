# Architecture decision records

An ADR captures a decision that is expensive to reverse, the context that forced it,
and the consequences we accept. The goal is to make the reasoning reviewable without
reading the whole history.

## Index

| ADR | Decision | Status | Phase |
|---|---|---|---|
| [001](ADR-001-vnet-flow-logs.md) | Use VNet flow logs instead of NSG flow logs | Accepted | 5 |
| [002](ADR-002-direct-spoke-peering.md) | Keep direct spoke-to-spoke peering until the firewall path is verified | Accepted (temporary) | 6 |
| [003](ADR-003-connector-token-handling.md) | Stage connector token handling: cloud-init first, Key Vault later | Accepted | 3 → 4 |
| [006](ADR-006-nat-then-firewall.md) | NAT Gateway as interim egress, Azure Firewall as the target | Accepted | 2 → 6 |

ADR-004 (Twingate instead of Bastion), ADR-005 (separate flow-log storage), and
ADR-007 (Firewall Basic SKU) are written before the phases that depend on them.

## Rules

- One decision per ADR.
- Write it **before** the code it justifies.
- ADRs are immutable once accepted: to change a decision, add a new ADR and mark the
  old one `Superseded by ADR-NNN`.
- Use [`TEMPLATE.md`](TEMPLATE.md) as the starting point.
- Link the ADR from the PR, the README trade-offs, and the threat model when relevant.

## Status values

| Status | Meaning |
|---|---|
| `Proposed` | Under discussion; not yet binding. |
| `Accepted` | The current decision. |
| `Superseded by ADR-NNN` | Replaced; kept for history. |
| `Deprecated` | No longer relevant, but not replaced. |
