# zero-trust-azure: Roadmap

Companion to [`SPEC.md`](./SPEC.md). The spec says *what and why*; this file says *in what order, how to check it, and what to show*.

**Status legend:** Not Started, In Progress, Blocked, At Risk, Done, Skipped

**Last updated:** 2026-10-20

---

## 1. Overview

| Order | Phase | Theme | Effort | Cost while testing | Status |
|---|---|---|---|---|---|
| 1 | **0** | Documentation foundation | ~0.5 weekend | none | Skipped |
| 2 | **1** | Automation and guardrails | ~1 weekend | none | Done |
| 3 | **2** | Controlled egress (NAT) + hub-access subnet | ~0.5 weekend | low (NAT GW) | Not Started |
| 4 | **3** | Identity-based access (Twingate + Entra ID) | ~1.5 weekends | low (1 VM + NAT) | Not Started |
| 5 | **4** | Workloads, managed identity, Key Vault | ~1 weekend | low (3 VMs) | Not Started |
| 6 | **5** | Observability (VNet flow logs, KQL, alerts) | ~1 weekend | low | Not Started |
| 7 | **6** | Hub inspection (Azure Firewall) | ~1 weekend | **high if left on** | Not Started |
| 8 | **7** | Stretch (pick one) | optional | varies | Not Started |

Total: roughly 6 to 7 weekends. Phases 0 to 5 already make a strong portfolio project; Phase 6 is the headline upgrade.

### Sequencing note (a change from the first draft)

Earlier I listed the firewall as part of "Phase 2". In this roadmap it is **Phase 6**, after workloads and monitoring. Reasons: you can only prove the new path works with real VMs (Phase 4), and the payoff of the firewall is seeing inspected flows in logs (Phase 5). The cheap NAT Gateway covers the connector's internet access in the meantime, and the temporary "Internet:443" rule is removed in Phase 6.

## 2. Dependency map

```
Phase 0 ──► Phase 1 ──► Phase 2 ──► Phase 3 ──► Phase 4 ──► Phase 5 ──► Phase 6 ──► Phase 7
 docs        CI/tests    NAT +        Twingate    VMs, KV,     flow logs    Firewall,   stretch
                         hub-access   connector   MI, verify   KQL, alerts  remove
                                                  script                    direct peering

Cross-links:
  Phase 3 needs Phase 2 (connector internet) and the private DNS hub link (R3.3)
  Phase 4 R4.6 upgrades Phase 3's token handling (cloud-init -> Key Vault)
  Phase 6 needs Phase 4 (VMs to test) and Phase 5 (logs to prove and to derive the FQDN allow-list)
  Every phase: tests (.tftest.hcl) land in the same PR as the code
```

## 3. Working agreements

- **One phase = one commit series on `master` = module release tags.** This is a learning project, so work goes directly to `master` without PRs; CI must be green after each push (from Phase 1 on).
- Costly resources stay behind flags (see SPEC 6.3). `make down` at the end of every session.
- Every deliberate hole in default-deny goes in the README "Accepted exceptions" table in the same PR that adds it.
- Write the ADR *before* the code it justifies.
- Capture evidence as you go: one screenshot or command output per phase, saved under `docs/evidence/`.
- Verify uncertain platform facts when you reach them (see SPEC section 14); do not trust memory for policy GUIDs, Twingate limits, or FQDN lists.

---

## Phase 0: Documentation foundation

**Goal:** the README explains its own limits before anything new is built.
**Spec:** R0.1 to R0.4

Checklist
- [ ] `docs/THREAT-MODEL.md` seeded from SPEC 9.1, each control linked to a file path
- [ ] README: "Accepted exceptions" table (flow register F1 now, others added as they land)
- [ ] README: "Known trade-offs" (PE subnet without NSG, direct spoke peering, connector token handling)
- [ ] `docs/adr/` with template; write ADR-001 (VNet flow logs), ADR-002 (direct peering), ADR-006 (NAT then Firewall)
- [ ] `docs/evidence/` folder created

Done when: a reader can learn the design's weak points from the README without reading code.

---

## Phase 1: Automation and guardrails

**Goal:** a bad change cannot merge; zero-trust invariants are tested.
**Spec:** R1.1 to R1.7, tests T1 to T8

Checklist
- [x] `.github/workflows/ci.yml`: fmt-check, per-module validate (no backend), tflint, Checkov
- [x] Scanner config with a justified-skip list (every skip has a reason)
- [x] `modules/network/tests/network.tftest.hcl`: T1, T2, T3, T7 (use `mock_provider "azurerm"`, `command = plan`, `expect_failures` for the overlap test)
- [x] `modules/storage/tests/storage.tftest.hcl`: T4
- [x] Tag test T8 across modules
- [x] `make test` target; CI runs it offline
- [x] Speculative plan in CI via the `TF_TOKEN` secret; the HCP cloud backend runs it remotely and CI cannot apply
- [x] `.pre-commit-config.yaml` with terraform-docs; `make hooks`
- [x] Extra policies in `module.policy` (built-in IDs verified with `az policy definition list`; custom definition for "no inbound 22/3389 from *"); tag policies start as Audit
- [x] Modules published from the VCS-backed private registry at v1.1.0 — releases are git tags (`network-vX.Y.Z`, `storage-vX.Y.Z`, `policy-vX.Y.Z`)
- [ ] Branch protection requiring CI — consciously deferred: this project commits directly to `master` (no PR flow)

Evidence: a deliberately broken NSG rule failed `terraform test` locally; the clean workflow passes in CI.
Done when: the bad change fails, the clean run passes in under 5 minutes, tests run without Azure credentials.

Watch out: Checkov will flag things like customer-managed keys and geo-replication; skip with a written reason, do not blanket-skip.

---

## Phase 2: Controlled egress (NAT) and hub-access subnet

**Goal:** a place for the connector to live, with a deliberate, temporary way out.
**Spec:** R2.1 to R2.4

Checklist
- [ ] ADR-006 written
- [ ] `hub-access` subnet 10.0.4.0/27 + NSG with deny-all baseline (T1 passes)
- [ ] `module.egress` NAT mode: NAT Gateway + public IP on `hub-access`, behind `deploy_egress_nat`
- [ ] `hub-access` NSG: outbound TCP/443 to `Internet` service tag, tagged as temporary
- [ ] Add to accepted-exceptions table: "temporary Internet:443 from hub-access (removed Phase 6)"
- [ ] Output NAT public IP
- [ ] Test: NAT policy interplay (does the NIC public-IP policy object?) (Q4)

Done when: `deploy_egress_nat=true` applies cleanly and only `hub-access` has NAT.

---

## Phase 3: Identity-based access (Twingate + Entra ID)

**Goal:** developers and auditors get different access to the same private network, with no inbound ports and no VPN.
**Spec:** R3.1 to R3.9

Before starting
- [ ] Q1: check current Twingate free-plan limits and Entra group sync availability
- [ ] Q2: confirm you have an Entra tenant with rights to create test users and groups
- [ ] ADR-003 (token handling) and ADR-004 (Twingate vs Bastion) written

Checklist
- [ ] Link `privatelink.blob.core.windows.net` to **hub** and **spoke2** VNets (R3.3) and test `nslookup` from the connector first
- [ ] `module.access`: remote network, connector, connector tokens (`Twingate/twingate` provider)
- [ ] Connector VM: Ubuntu LTS, no public IP, SSH public key via variable, cloud-init installs the connector
- [ ] Twingate API key + network name as sensitive HCP workspace variables
- [ ] NSG: connector -> spoke-workload (22, 443); outbound from `hub-access` to spoke-workload and the PE subnet (443)
- [ ] Twingate Resources: test VM SSH, test VM HTTPS, storage FQDN:443
- [ ] Console steps: Entra IdP integration, group sync, create `zt-developers` and `zt-auditors` (document in `docs/RUNBOOK-twingate.md`)
- [ ] Group policies: developers -> all three resources; auditors -> storage only
- [ ] Update accepted-exceptions table (F2, F3, F5) and threat model

Note: Phase 3 needs a target VM. Either pull the minimal VM 1 from Phase 4 forward or use the connector VM itself as the SSH target for the first test; then migrate the resource definition when VM 1 exists.

Evidence: short screen recording of developer vs auditor against the same resources.
Done when: the developer reaches all three; the auditor reaches only storage and is denied SSH.

Watch out: if resolution returns a public IP, the DNS link is missing. Fix that before debugging Twingate.

---

## Phase 4: Workloads and data-plane identity

**Goal:** workloads authenticate by identity, secrets leave the picture, and a script proves the matrix.
**Spec:** R4.1 to R4.9, verification matrix V1 to V15

Before starting
- [ ] Q5: test how `az vm run-command` and the guest agent behave under DenyAllOutbound 4096 (use a throwaway VM)

Checklist
- [ ] `module.compute`: VM 1 (spoke), VM 2 (spoke2), system-assigned identities, public-key SSH, no public IPs
- [ ] cloud-init for VM 1: HTTPS on 443 with a self-signed cert using only preinstalled `python3` and `openssl` (no `apt install`)
- [ ] Storage: `shared_access_key_enabled = false` and provider `storage_use_azuread = true`; confirm Terraform still manages containers
- [ ] RBAC: VM 1 identity -> `Storage Blob Data Reader`; developers group -> reader/contributor
- [ ] Seed a test blob (document how)
- [ ] `module.keyvault`: RBAC mode, public access off, purge protection, PE in `spoke-private-endpoints`, `privatelink.vaultcore.azure.net` zone linked to hub/spoke/spoke2
- [ ] Move connector token to Key Vault; connector VM fetches it with its managed identity (F4); remove token from `custom_data`
- [ ] `scripts/verify-connectivity.sh` via `az vm run-command invoke`: all rows V1 to V11, V15, PASS/FAIL table, non-zero exit on mismatch
- [ ] Update accepted exceptions (F4, F6, F7) and ADR-003 outcome
- [ ] (P2) manual `workflow_dispatch` to run the script with OIDC

Evidence: the PASS/FAIL table output.
Done when: all rows match expectation, the connector survives the token migration, and `az storage blob list --auth-mode key` is rejected.

---

## Phase 5: Observability

**Goal:** every negative test leaves a findable trace.
**Spec:** R5.1 to R5.6

Before starting
- [ ] ADR-001 and ADR-005 final
- [ ] Q6: check whether `azurerm` 4.81.0 supports VNet-targeted flow logs natively or needs `azapi`

Checklist
- [ ] `module.monitoring`: Log Analytics workspace, short retention, daily cap
- [ ] Dedicated flow-log storage account (not the private-only one)
- [ ] VNet flow logs on hub, spoke, spoke2 (use VNet flow logs; NSG flow logs cannot be created and retire 2027-09-30)
- [ ] Diagnostic settings: Key Vault audit, storage blob logs, NSG events
- [ ] Saved KQL in `docs/kql/`: denied flows by source; connector-subnet flows; Key Vault access by identity; failed storage auth
- [ ] Defender for Cloud free-tier review -> `docs/SECURITY-POSTURE.md`
- [ ] One alert rule (denied-flow spike or Key Vault failed auth) with email
- [ ] Run `verify-connectivity.sh`, then confirm each negative row appears in KQL

Evidence: a KQL result showing the denied packet from a negative test.
Done when: every deny row in the matrix (V2 to V5, V7, V10) has a matching log record found by a saved query.

Watch out: flow log and Log Analytics ingestion are not instant; allow time before concluding a log is missing.

---

## Phase 6: Hub inspection (Azure Firewall)

**Goal:** the hub becomes a real control point; direct peering and broad egress go away.
**Spec:** R6.1 to R6.8

Before starting
- [ ] ADR-002 and ADR-007 final
- [ ] Budget alert in place; remember this is the expensive phase

Checklist
- [ ] Add `AzureFirewallSubnet` (10.0.2.0/26) and `AzureFirewallManagementSubnet` (10.0.3.0/26)
- [ ] Azure Firewall Basic + policy + public IPs behind `deploy_firewall`; diag logs to Log Analytics
- [ ] Network rule: spoke2-workload -> spoke-workload 443 (F1)
- [ ] Route tables: `0.0.0.0/0` and inter-spoke prefixes next hop = firewall; attach to workload and `hub-access` subnets (T6)
- [ ] Set `enable_direct_spoke_peering = false`; re-run matrix; F1 still passes via firewall
- [ ] Start with a permissive application rule for the connector, then **derive the FQDN allow-list from the firewall deny/allow logs**; tighten to that list
- [ ] Remove the `Internet:443` allow from `hub-access` NSG; connector stays Online
- [ ] Revisit NSG prefixes for F1/F2 (source address seen at the destination may differ after the path change)
- [ ] `docs/EGRESS-ALLOWLIST.md` documenting the final list and how it was found
- [ ] Update accepted exceptions: F1 via firewall, F5 via FQDN rules, temporary rule removed
- [ ] Demo, capture evidence, then `make down`

Evidence: firewall log line for V1 (allowed) and V5 (denied).
Done when: matrix passes with no direct peering, connector only reaches allow-listed FQDNs, firewall destroyed after the demo.

---

## Phase 7: Stretch (pick at most one)

- [ ] Multi-environment (dev/staging) with workspaces or tfvars and module-version promotion
- [ ] Private DNS Resolver + more private endpoints (SQL, ACR)
- [ ] Container Apps or AKS in a spoke with network policies as a second segmentation layer

Only start after Phases 0 to 6 are Done or consciously deferred.

---

## 4. Risks and dependencies (rolling)

| Risk / dependency | Phase | Status | Mitigation |
|---|---|---|---|
| Twingate free-plan limits unknown (Q1) | 3 | Open | Check before starting; fallback is a minimal resource set |
| Need Entra tenant rights (Q2) | 3 | Open | Confirm before starting |
| Private DNS not linked to hub | 3 | Known | Do R3.3 first |
| Default-deny outbound breaks cloud-init installs | 3, 4 | Known | No `apt install`; use preinstalled tools |
| run-command behavior under deny-all (Q5) | 4 | Open | Test with a throwaway VM early |
| Firewall left running | 6 | Known | Flags, `make down`, budget alert |
| Mocked tests give false confidence | 1 | Known | Keep HCP speculative plan |

## 5. Session routine

Start of session
1. `git pull`, `make fmt-check`, `make test`
2. Pick the next unchecked item in the current phase
3. Write or update the ADR first if the item has a decision in it

End of session
1. `make verify` (once it exists) and update accepted-exceptions table if a rule changed
2. Save evidence into `docs/evidence/`
3. **`make down`** (nothing costly left running)
4. Tick the checklist, update the status table at the top of this file

## 6. Final deliverables

- Updated diagrams (Excalidraw -> SVG in `docs/diagrams/`): topology with firewall, access flow (Twingate + Entra), observability
- README sections: Overview, Access model, Verification, Monitoring, Accepted exceptions, Known trade-offs, Cost, Teardown
- `docs/`: THREAT-MODEL, RUNBOOK-twingate, SECURITY-POSTURE, EGRESS-ALLOWLIST, ADRs, KQL, evidence
- A 3 to 5 minute demo script: run the matrix, show developer vs auditor, find a denied packet in KQL, show the CI rejecting a bad PR

### Resume bullets (use only what you have actually built)

- Built a default-deny hub-and-spoke Azure network in Terraform (private module registry, OIDC to HCP Terraform) with CI security scanning and offline `terraform test` invariants.
- Implemented identity-based ZTNA with Twingate and Entra ID: group-scoped access to private endpoints and VMs with zero inbound ports and zero public IPs on workloads.
- Eliminated shared secrets: disabled storage shared-key auth, used managed identities and RBAC, and kept secrets in a private-endpoint-only Key Vault.
- Added controlled egress and central inspection with Azure Firewall FQDN rules derived from log analysis, replacing direct spoke peering.
- Instrumented the network with VNet flow logs and Log Analytics; automated a 15-row connectivity matrix that proves both allowed and denied paths.

## 7. Parking lot

- Multi-region and DR
- Conditional Access and device posture beyond what Twingate's tier offers
- Policy-as-code with OPA/Conftest in addition to Checkov
- Cost dashboard in the README via `az consumption`

## 8. Change log

| Date | Change |
|---|---|
| 2026-10-20 | Phase 1 done: CI (fmt, validate, test, tflint, Checkov, remote plan via TF_TOKEN), offline T1-T4/T7/T8 tests, network module 1.1.0 and policy module 1.1.0, extra policy assignments. Phase 0 skipped. Branch protection deferred (direct-to-master workflow). |
| 2026-10-18 | Initial roadmap. Firewall moved from Phase 2 to Phase 6; flow-log approach changed from NSG to VNet flow logs (NSG flow logs cannot be created and retire 2027-09-30). |
