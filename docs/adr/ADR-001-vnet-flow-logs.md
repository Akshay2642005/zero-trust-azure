# ADR-001: Use VNet flow logs instead of NSG flow logs

- **Status:** Accepted
- **Date:** 2026-10-19
- **Deciders:** Akshay
- **Related:** SPEC R5.1–R5.6, roadmap Phase 5, open question Q6

## Context

Phase 5 must make network decisions observable: every allow and deny in the
verification matrix should be findable in a log. The obvious choice is NSG flow
logs, but NSG flow logs can no longer be created for new resources, and they retire
on **2027-09-30**. Building the project on a retiring feature would be a poor
portfolio decision and a maintenance trap.

VNet flow logs cover the same traffic at the virtual-network scope and are the
supported replacement. Their availability in the `azurerm` provider at the pinned
version (4.81.0) is open question Q6; if the provider does not expose them natively,
`azapi` is the fallback.

## Decision

Use **VNet flow logs** on the hub and both spokes, writing to a dedicated flow-log
storage account and to a Log Analytics workspace with a short retention period and
a daily ingestion cap.

- If `azurerm` 4.81.0 supports the VNet-targeted resource, use it.
- Otherwise, use `azapi_resource` for the flow-log resource and keep the rest in
  `azurerm`.
- Saved KQL queries live in `docs/kql/`; one alert covers denied-flow spikes.

## Consequences

### Positive

- Uses a supported feature with a multi-year runway.
- One flow log per VNet, instead of one per NSG.
- The same logs can drive the Phase 6 FQDN allow-list.

### Negative / accepted costs

- Flow-log storage and Log Analytics ingestion cost money; a daily cap and short
  retention bound it.
- Logs are not instant. The Phase 5 verification must allow ingestion time before
  concluding a record is missing.
- Q6 may force an `azapi` escape hatch, which is less consistent than the rest of
  the codebase.

## Alternatives considered

| Alternative | Why not |
|---|---|
| NSG flow logs | Cannot be created; retire 2027-09-30. |
| Packet capture on each VM | Heavy, VM-local, and does not see NSG denies. |
| Azure Firewall logs only | The firewall arrives in Phase 6; Phases 1–5 would be blind, and east-west traffic still needs VNet-level visibility. |

## Review

Revisit at the start of Phase 5 after confirming Q6 against the provider
documentation. If the provider gains native support later, remove the `azapi`
fallback.
