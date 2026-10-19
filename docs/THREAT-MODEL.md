# Threat model

**Scope:** the `zt-rg` resource group and the Terraform, CI, and identity plumbing
that deploys it.
**Last reviewed:** 2026-10-19 (Phase 0)
**Owner:** Akshay
**Companion documents:** [`SPEC.md` §9](../SPEC.md), [`ROADMAP.md`](../ROADMAP.md),
[`docs/adr/`](adr/).

This is a living document. A control is only listed as **Implemented** when it
exists in this repository today. Anything forward-looking is marked **Planned** with
the phase that lands it, so the gap is visible rather than implied.

---

## 1. Method

For each threat we record:

1. the **threat** in concrete terms;
2. the **control** that reduces it;
3. **where** the control lives (a file path, a resource, or a planned module);
4. **how it is verified** (a test ID, a verification-matrix row, a command, or a review);
5. the **status** today.

The default posture is deny. The complete list of allowed flows is the flow register
in [`SPEC.md` §6.4](../SPEC.md); the README mirrors it in
[Accepted exceptions](../README.md#accepted-exceptions). Anything not in that table
must be denied by the NSGs.

---

## 2. Threats and controls

| # | Threat | Control | Where | Verified by | Status |
|---|---|---|---|---|---|
| 1 | **Lateral movement between workloads.** A compromised VM reaches another segment or an unrelated port. | Per-subnet default-deny NSGs (inbound and outbound at priority 4096), one documented flow (F1), no shared flat network. | [`modules/network/main.tf`](../modules/network/main.tf) — `azurerm_network_security_group` and the peering pair; [`envs/dev/main.tf`](../envs/dev/main.tf) | T1, T2, T3 (Phase 1 tests); V2–V5 (Phase 4); flow logs (Phase 5) | **Implemented** (NSGs, peering); tests **Planned — Phase 1** |
| 2 | **Public exposure of data.** A storage account, endpoint, or workload is reachable from the internet. | Storage public network access disabled, nested public blobs disabled, TLS 1.2 minimum, HTTPS-only, private endpoint, private DNS; policy denies public storage and public IPs on NICs. | [`modules/storage/main.tf`](../modules/storage/main.tf); [`modules/policy/main.tf`](../modules/policy/main.tf); [`envs/dev/locals.tf`](../envs/dev/locals.tf) | T4, T5, V15; `az storage blob list --auth-mode key` must fail (Phase 4) | **Implemented** for network access; **Planned — Phase 1** for the extra policy guardrails |
| 3 | **Credential or key theft.** A secret in the repo, state, CI logs, or VM metadata is used to reach Azure. | OIDC federation for Terraform runs (no stored Azure client secret); no account keys in the repo; managed identities and Key Vault planned. Storage shared-key auth is still enabled today. | [`scripts/setup-oidc.rb`](../scripts/setup-oidc.rb); [`envs/dev/backend.tf`](../envs/dev/backend.tf); [`modules/storage/main.tf`](../modules/storage/main.tf) (`shared_access_key_enabled`); future `modules/keyvault` | R3.7 (“no secret printed”); V6, V8 (Phase 4); review of CI logs | **Partial.** OIDC is implemented; shared-key auth and Key Vault are **Planned — Phase 4** |
| 4 | **Unauthorized remote access.** Someone reaches a VM, the connector, or storage over SSH/RDP or a public endpoint. | Default-deny NSGs; no public IPs on workloads; T3 invariant for 22/3389; policy denying public IPs on NICs; ZTNA with group-scoped resources planned. | [`modules/network/main.tf`](../modules/network/main.tf); [`modules/policy/main.tf`](../modules/policy/main.tf); future `modules/access` | T3, T5 (Phase 1); V12–V14 (Phase 3); Twingate policy review | **Partial.** Network baseline exists; there are no workload VMs yet; ZTNA is **Planned — Phase 3** |
| 5 | **Config drift / insecure PR.** A public IP, an open NSG rule, or a weak storage setting is merged by hand or by an unreviewed change. | CI runs fmt, validate, tflint, and a security scanner; `terraform test` asserts the invariants; Azure Policy denies/audits the same properties; branch protection requires the checks. | `.github/workflows/ci.yml` and `modules/*/tests` (**Planned — Phase 1**); `envs/dev/policies.tf` (**Planned — Phase 1**); [`modules/policy/main.tf`](../modules/policy/main.tf) | R1.1–R1.3, R1.6, R1.7; T1–T8 | **Planned — Phase 1** |
| 6 | **Undetected attack.** A denied or allowed packet leaves no trace, so an incident cannot be reconstructed. | VNet flow logs on hub and both spokes; Log Analytics workspace with a daily cap; diagnostic settings; saved KQL queries; one alert on denied-flow spikes or failed Key Vault auth. | Future `modules/monitoring`; `docs/kql/`; [`ROADMAP.md` Phase 5](../ROADMAP.md) | R5.4, R5.6; each negative row (V2–V5, V7, V10) must appear in a saved query | **Planned — Phase 5** |
| 7 | **Data exfiltration via egress.** A compromised workload sends data to an arbitrary internet destination. | Egress only through a controlled path: interim NAT Gateway for the connector, then Azure Firewall with an FQDN allow-list derived from logs; the temporary `Internet:443` rule is removed. | Future `modules/egress`; `deploy_egress_nat` / `deploy_firewall` flags in [`SPEC.md` §6.3](../SPEC.md); [`docs/adr/ADR-006`](adr/ADR-006-nat-then-firewall.md) | V5; R6.5; firewall logs (Phase 6) | **Planned — Phases 2 and 6** |
| 8 | **Compromised CI credentials.** A stolen token or over-privileged runner changes production. | OIDC dynamic credentials; no long-lived Azure secret; plan-only on PR; least-privilege roles (`Contributor` + `Resource Policy Contributor` at subscription scope); the HCP token is scoped to one workspace and skipped for fork PRs. | [`scripts/setup-oidc.rb`](../scripts/setup-oidc.rb); `.github/workflows/ci.yml` (**Planned — Phase 1**); HCP workspace settings | Review; R1.4 (speculative plan never applies); `git grep` for secrets | **Partial.** OIDC is implemented; CI hardening is **Planned — Phase 1** |

---

## 3. Residual risks and accepted gaps

These are known and accepted for the lab. Each has an exit condition; until then it
is a documented weakness, not an oversight.

| Risk | Why it exists | Impact | Exit |
|---|---|---|---|
| Storage shared-key auth is enabled (`shared_access_key_enabled = true` by default) | Module default preserves the existing behaviour; Phase 4 moves to Entra ID/RBAC | A stolen account key grants data-plane access, bypassing identity controls | Phase 4: set it to `false`, use managed identities, verify V8 |
| Private-endpoints subnet has no NSG | Private Link traffic can be dropped before it reaches the endpoint; the subnet only hosts endpoints | No subnet-level microsegmentation on that subnet | Revisit if the subnet hosts anything else; add a narrow NSG |
| Direct spoke-to-spoke peering | The hub has no NVA; it is the only path for F1 today | F1 bypasses a central inspection point | Phase 6: firewall path, then `enable_direct_spoke_peering = false` (ADR-002) |
| Connector token in cloud-init during Phase 3 | Fastest bootstrap; Key Vault arrives in Phase 4 | Token visible in VM metadata/custom_data and Terraform state | Phase 4: managed identity + Key Vault (ADR-003) |
| Broad `Internet:443` egress from `hub-access` during Phases 2–5 | The connector must reach Twingate before the firewall exists | A compromised connector can reach any HTTPS destination | Phase 6: FQDN allow-list and removal of the rule (ADR-006) |
| Mocked-provider tests can miss provider behaviour | Offline tests must run without Azure credentials | A regression that only appears in a real plan could pass | Keep the HCP speculative plan on PRs; run the live verification matrix |
| The firewall is expensive if left running | Azure Firewall Basic is roughly $300/month | Cost, not security | `deploy_firewall = false` by default; `make down` after demos; budget alert |

---

## 4. Out of scope

The following are deliberately not modelled here:

- compromise of the Azure platform or Microsoft Entra ID itself;
- DDoS and volumetric attacks (Azure edge protection is assumed);
- host OS hardening, patching, and endpoint detection on the VMs;
- application-layer vulnerabilities inside a workload;
- data classification, retention, and privacy obligations;
- multi-region disaster recovery (see the parking lot in the roadmap).

---

## 5. Review triggers

Review this document in the same PR when any of these happen:

- a new resource type or module is added;
- a new allowed flow is introduced (add it to the flow register and the README);
- a new secret, key, or credential enters the design;
- a phase is completed;
- an incident or a near miss is found.

The threat model is only useful if it is updated before the control, not after.
