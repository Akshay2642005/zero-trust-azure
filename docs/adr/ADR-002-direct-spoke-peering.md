# ADR-002: Keep direct spoke-to-spoke peering until the firewall path is verified

- **Status:** Accepted (temporary)
- **Date:** 2026-10-19
- **Deciders:** Akshay
- **Related:** SPEC R6.1–R6.8, F1 in the flow register, roadmap Phases 1 and 6

## Context

The hub-and-spoke topology has no network virtual appliance. A pure hub-and-spoke
design does not route between spokes, so the one allowed flow (F1: spoke2-workload
to spoke-workload on 443) needs either a direct peering or a transit path through
an NVA or firewall.

The current environment already has a direct `spoke` ↔ `spoke2` peering. Building
the firewall now would make Phase 1 expensive and would delay the cheap, testable
baseline. Building an NVA would add operational work without adding inspection
policy.

## Decision

Keep the direct spoke-to-spoke peering for now. It is the path for F1 until the
Azure Firewall path is deployed and verified in Phase 6.

- The peering pair stays in `modules/network`.
- A `enable_direct_spoke_peering` flag will be added with the firewall work; the
  default stays `true` until the new path passes the matrix, then flips to `false`.
- F1 is documented as an accepted exception and a known trade-off in the README.

## Consequences

### Positive

- Phase 1–5 stay cheap and can be tested without a firewall.
- F1 is explicit and covered by NSG rules on both sides.
- The eventual migration is a route-table and peering change, not a redesign.

### Negative / accepted costs

- F1 bypasses a central inspection point. A compromised spoke2 workload can reach
  spoke1 directly; only the NSGs constrain it.
- The temporary state must not become permanent. The exit condition is explicit:
  Phase 6, after the firewall path passes the matrix.

## Alternatives considered

| Alternative | Why not |
|---|---|
| Deploy Azure Firewall in Phase 1 | Roughly $300/month; the expensive phase should come after workloads and logs exist. |
| Add an NVA now | Extra VM, extra failure mode, and no policy benefit over the firewall. |
| Deny F1 until Phase 6 | Removes the only cross-segment flow the project is meant to demonstrate. |

## Review

Phase 6. Do not mark this ADR `Superseded` until `enable_direct_spoke_peering = false`
has been applied and the full matrix passes through the firewall.
