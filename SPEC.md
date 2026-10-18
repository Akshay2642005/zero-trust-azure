# zero-trust-azure: Enhancement Specification

| | |
|---|---|
| **Status** | Draft v1 |
| **Owner** | Akshay |
| **Repo** | `Akshay2642005/zero-trust-azure` |
| **Companion doc** | [`ROADMAP.md`](./ROADMAP.md) (sequencing, checklists, demo scripts) |
| **Baseline** | Terraform >= 1.9, `azurerm` 4.81.0, HCP Terraform workspace `zero-trust-azure-dev`, OIDC dynamic credentials, modules `network` / `storage` / `policy` at v1.0.0 in the private registry |

---

## 1. Problem statement

The repository today proves the *network* half of zero trust: a default-deny hub-and-spoke fabric, one deliberately narrow allowed flow, a private-only storage account, and one guardrail policy. Three things are missing, and they are exactly what a reviewer will probe:

1. **Nobody is verifying the claims.** There is no CI, no policy-as-code scanning, and no automated test that asserts "default deny holds".
2. **No identity layer.** Nothing governs *who* can reach private resources. There is no remote-access story, and no data-plane identity (storage still allows shared keys by default).
3. **No visibility or central control.** The hub is empty (no inspection, no egress control), and there are no flow logs, so there is no way to show a denied packet.

This spec defines the work to close those gaps so the project demonstrates **build, verify, access-control, and observe**, not just "I wrote Terraform".

## 2. Goals

| ID | Goal | Measurable outcome |
|---|---|---|
| G1 | Every change is validated automatically | A PR with an intentionally bad change (e.g. an NSG allow from `*` to port 22) fails CI; a clean PR passes in under 5 minutes |
| G2 | Zero-trust properties are asserted, not asserted-in-prose | `terraform test` suite covers the invariants in section 7.2 and runs in CI |
| G3 | Access is identity-based and role-scoped | Two Entra groups get different outcomes against the same Twingate resources, demonstrated live; zero inbound ports and zero public IPs on workloads |
| G4 | Workloads authenticate with identity, not secrets | Storage `shared_access_key_enabled = false`; the spoke VM reads a blob with a managed identity; no secrets in code |
| G5 | Denied traffic is provable | For each negative test in the matrix (section 8) a corresponding flow-log record is findable by a saved KQL query |
| G6 | The hub does real work | Spoke-to-spoke and egress traffic traverse a central control point (NAT first, Azure Firewall later) |
| G7 | Cost stays controlled | Costly components are behind flags, default off; one `make down` leaves zero billable resources |

## 3. Non-goals

| Non-goal | Why |
|---|---|
| Multi-region / DR | Large effort, little extra learning for this scope. Parking lot. |
| Production-grade firewall HA, zones, forced tunneling | Azure Firewall is used to learn the pattern, not run 24/7. |
| Conditional Access / Entra P1/P2 licensed features | Licensing dependency; use whatever Twingate and the Entra free tier allow. |
| A real business application | Test workloads exist only to exercise network and identity paths. |
| AKS / Container Apps in the spoke | Phase 7 stretch only. |
| Replacing HCP Terraform | Keep the existing backend and OIDC setup. |

## 4. Personas and user stories

**Maintainer (Akshay)**
- As the maintainer, I want CI to reject insecure Terraform so that I cannot regress the zero-trust posture by accident.
- As the maintainer, I want one command to bring up and tear down the whole costly environment so that I can demo cheaply.
- As the maintainer, I want every deliberate hole in default-deny listed in one register so that I can explain each one.

**Remote developer (Entra group `zt-developers`)**
- As a developer, I want to reach the test VM over SSH and read the storage account from my laptop without a VPN or public IP so that access is simple and the network stays closed.
- As a developer, I want denied attempts to fail fast with no ambiguity about why.

**Auditor (Entra group `zt-auditors`)**
- As an auditor, I want read-only reachability to the storage endpoint but no shell access so that I can verify data without being able to change the environment.

**Reviewer (interviewer / recruiter)**
- As a reviewer, I want a threat model table, a connectivity test matrix, and a short demo script so that I can confirm the claims in minutes.

## 5. Current state (baseline, from the repo)

| Area | Today |
|---|---|
| Fabric | `hub-vnet` 10.0.0.0/16, `spoke-vnet` 10.1.0.0/16, `spoke2-vnet` 10.2.0.0/16; hub is empty (`hub-default` 10.0.1.0/24 only) |
| Subnets | `hub-default` 10.0.1.0/24, `spoke-workload` 10.1.0.0/24, `spoke-private-endpoints` 10.1.1.0/24 (no NSG, intentionally), `spoke2-workload` 10.2.0.0/24 |
| NSGs | `hub-nsg`, `spoke-nsg`, `spoke2-nsg`, all with DenyAllInbound/DenyAllOutbound at 4096 from one `deny_all_rules` map |
| Allowed flow | spoke2 workload -> spoke1 workload TCP/443 via two priority-100 rules (egress on spoke2 NSG, ingress on spoke NSG) |
| Routing | Hub<->spoke, hub<->spoke2 peerings plus a **direct spoke<->spoke2 peering** (no NVA, so no central inspection) |
| Storage | StorageV2, TLS 1.2, public network access off, nested public off, blob soft delete, **private endpoint + `privatelink.blob.core.windows.net` zone linked to spoke VNet only** |
| Policy | One assignment: built-in "network interfaces should not have public IPs" at resource-group scope |
| Delivery | HCP Terraform + OIDC (`scripts/setup-oidc.rb`), modules published to the private registry (`scripts/publish-module.sh`), `Makefile` wrappers |
| Missing | CI, tests, scanning, compute, identity layer, Key Vault, logging, egress control, threat model |

## 6. Target architecture

### 6.1 Address plan

Existing ranges are unchanged. New ranges are additive.

| VNet | Subnet | CIDR | Purpose | Phase |
|---|---|---|---|---|
| hub | `hub-default` | 10.0.1.0/24 | existing, keep | n/a |
| hub | `hub-access` | 10.0.4.0/27 | Twingate connector(s) (room for 2) | 3 |
| hub | `AzureFirewallSubnet` | 10.0.2.0/26 | Azure Firewall (name is mandatory) | 6 |
| hub | `AzureFirewallManagementSubnet` | 10.0.3.0/26 | required for Firewall Basic SKU (name is mandatory) | 6 |
| spoke | `spoke-workload` | 10.1.0.0/24 | test VM 1 (HTTPS server + SSH) | 4 |
| spoke | `spoke-private-endpoints` | 10.1.1.0/24 | storage PE, Key Vault PE | 4 |
| spoke2 | `spoke2-workload` | 10.2.0.0/24 | test VM 2 (client) | 4 |

### 6.2 Module map

Existing modules are bumped to **v1.1.0** (additive, defaults preserve v1.0.0 behavior). New modules start at **v0.1.0**.

```
envs/dev
├── azurerm_resource_group.this
├── module.network      (v1.1.0)  + hub-access subnet, optional firewall subnets, route tables, connector NSG rules,
│                                   toggle for direct spoke<->spoke2 peering
├── module.storage      (v1.1.0)  + shared-key toggle wired, RBAC assignments input, extra DNS-zone links (hub, spoke2)
├── module.policy       (v1.1.0)  + custom definitions + initiative (deny SSH/RDP from *, require tags, TLS, storage public access)
├── module.egress       (v0.1.0)  NAT Gateway (Phase 2) / Azure Firewall + policy + UDRs (Phase 6)
├── module.access       (v0.1.0)  Twingate remote network, connector VM, groups, resources
├── module.keyvault     (v0.1.0)  Key Vault (RBAC, private endpoint, purge protection) + privatelink.vaultcore zone
├── module.compute      (v0.1.0)  test VM 1 / VM 2, system-assigned identities, cloud-init
└── module.monitoring   (v0.1.0)  Log Analytics, VNet flow logs, diagnostic settings, saved KQL, Defender plan
```

### 6.3 Feature flags (all in `envs/dev/variables.tf`)

| Variable | Default | Controls |
|---|---|---|
| `deploy_egress_nat` | `false` | NAT Gateway on `hub-access` |
| `deploy_firewall` | `false` | Azure Firewall, route tables, removal of direct spoke peering |
| `enable_direct_spoke_peering` | `true` | v1.0.0 behavior; set `false` once the firewall path is verified |
| `deploy_connector` | `false` | Twingate connector VM and resources |
| `deploy_test_vms` | `false` | VM 1 and VM 2 |
| `deploy_monitoring` | `true` | Log Analytics, flow logs (cheap at this scale) |

`make up` sets the demo profile; `make down` destroys it (see section 10).

### 6.4 Flow register (the complete list of allowed flows after all phases)

Everything not in this table must be denied. Each row is a documented exception to default-deny and must appear in the README "Accepted exceptions" table.

| # | Source | Destination | Port | Path | Introduced |
|---|---|---|---|---|---|
| F1 | spoke2-workload | spoke-workload | 443 | direct peering (now) -> via Firewall (Phase 6) | existing / 6 |
| F2 | hub-access (connector) | spoke-workload | 22, 443 | peering | 3 |
| F3 | hub-access (connector) | storage private endpoint | 443 | peering + private DNS | 3 |
| F4 | hub-access (connector) | Key Vault private endpoint | 443 | peering + private DNS | 4 |
| F5 | hub-access (connector) | Twingate cloud | 443 | NAT GW (Phase 2) -> Firewall FQDN rules (Phase 6) | 2 / 6 |
| F6 | spoke VM 1 | storage private endpoint | 443 | managed identity + RBAC | 4 |
| F7 | platform | VMs (guest agent, run-command) | n/a | Azure platform address, not NSG-controlled | 4 (verify) |

### 6.5 DNS

- `privatelink.blob.core.windows.net` is currently linked to the **spoke** VNet only. The connector lives in the **hub**, so the zone must also be linked to the hub VNet (and spoke2 for completeness). Without this, F3 fails with a public-IP resolution that is then blocked. This is the most likely first failure in Phase 3.
- Add `privatelink.vaultcore.azure.net` (Key Vault) in Phase 4 with the same three links.
- Twingate resources reference the storage account by its FQDN; the connector resolves it through the linked private zone.

## 7. Requirements

Priority: **P0** = phase cannot be called done without it, **P1** = should ship, **P2** = nice to have. Each requirement has acceptance criteria (AC).

### 7.1 Phase 0: Documentation foundation

| ID | Pri | Requirement | AC |
|---|---|---|---|
| R0.1 | P0 | `docs/THREAT-MODEL.md`: table of threat -> control -> file/resource -> how verified | Covers at least: lateral movement, public exposure of data, credential theft, unauthorized remote access, config drift, undetected attack. Every control links to a file path. |
| R0.2 | P0 | README section "Accepted exceptions" mirroring the flow register (6.4) | Table matches 6.4; updated whenever a rule changes |
| R0.3 | P0 | README section "Known trade-offs" | Lists PE subnet without NSG, direct spoke peering (until Phase 6), connector token handling |
| R0.4 | P1 | `docs/adr/` with ADR template and first ADRs (see section 13) | At least ADR-001..003 written before the phase that depends on them |

### 7.2 Phase 1: Automation and guardrails

| ID | Pri | Requirement | AC |
|---|---|---|---|
| R1.1 | P0 | GitHub Actions workflow `ci.yml` on PR and push to main: `terraform fmt -check`, `terraform validate` (backend disabled), `tflint`, security scan (`checkov` or `trivy config`) | A deliberately insecure PR fails; clean PR passes; workflow runtime < 5 min |
| R1.2 | P0 | Scanner config file with **justified** skips only | Every skipped check has a one-line reason (e.g. CMK encryption out of scope). No blanket skips. |
| R1.3 | P0 | `terraform test` suite in `modules/*/tests/*.tftest.hcl` using `mock_provider "azurerm"` and `command = plan` | Runs offline in CI (no Azure credentials); covers invariants below |
| R1.4 | P1 | Speculative plan on PR via HCP Terraform (VCS-driven or API) | PR shows plan summary; plan never applies from a PR |
| R1.5 | P1 | `pre-commit` config (fmt, validate, tflint, terraform-docs) | `make hooks` installs it; terraform-docs keeps module READMEs current |
| R1.6 | P1 | Extra policy guardrails in `module.policy` (see 7.2.2) | Each policy has an `enforce` toggle and appears in compliance report |
| R1.7 | P2 | Branch protection requiring CI | Documented setting; screenshot in README |

#### 7.2.1 Invariants asserted by `terraform test`

| Test | Assertion |
|---|---|
| T1 | Every NSG in `modules/network` contains `DenyAllInbound` and `DenyAllOutbound` at priority 4096 |
| T2 | No Allow rule has `destination_address_prefix` or `source_address_prefix` equal to `*`, `0.0.0.0/0`, or `Internet` unless listed in an explicit allow-list variable (the existing spoke2 egress rule uses source `*` and a specific destination; the test must express this precisely) |
| T3 | No Allow rule on port 22 or 3389 has a non-internal source |
| T4 | Storage: `public_network_access_enabled = false`, `min_tls_version = "TLS1_2"`, `allow_nested_items_to_be_public = false`; `shared_access_key_enabled = false` when the variable is set |
| T5 | No `azurerm_public_ip` exists in network/compute/access modules (firewall IPs are the only allowed exception, asserted in `egress` tests) |
| T6 | With `deploy_firewall = true`, route tables on workload and access subnets have `0.0.0.0/0` next hop = firewall private IP |
| T7 | VNet address spaces do not overlap (validation block, tested with a bad input via `expect_failures`) |
| T8 | Every taggable resource carries `managed-by`, `project`, `environment` |

#### 7.2.2 Additional policies

Implement as custom definitions in `module.policy` where no suitable built-in exists. **Look up built-in definition IDs with `az policy definition list` and verify before use; do not copy GUIDs from memory.**

| Policy | Effect |
|---|---|
| Storage accounts must disable public network access | Deny |
| Secure transfer / minimum TLS 1.2 on storage | Deny |
| NSG rules must not allow inbound 22/3389 from `*` or `Internet` | Deny (custom) |
| Resources must carry required tags | Deny or Audit (start Audit) |
| Existing: NICs must not have public IPs | Deny (existing) |

Caveat: the Azure Firewall public IP is attached to the firewall, not a NIC, but **verify** the NIC policy does not block it during Phase 6.

### 7.3 Phase 2: Controlled egress (NAT) and hub subnet

| ID | Pri | Requirement | AC |
|---|---|---|---|
| R2.1 | P0 | `hub-access` subnet 10.0.4.0/27 with its own NSG (deny-all baseline) | Subnet exists; NSG passes T1 |
| R2.2 | P0 | `module.egress` (NAT mode): NAT Gateway + public IP associated to `hub-access` | Gated by `deploy_egress_nat`; connector outbound reaches the internet; no other subnet gets NAT |
| R2.3 | P0 | `hub-access` NSG outbound allow: TCP/443 to `Internet` service tag (temporary, documented) | Rule carries a comment/ADR reference and is tracked as an accepted exception to be narrowed in Phase 6 |
| R2.4 | P1 | Output the NAT public IP | Visible in outputs for allow-listing and docs |

Note: new VNets have no implicit outbound internet access, so NAT (or Firewall) is required for the connector to reach Twingate.

### 7.4 Phase 3: Identity-based access (Twingate + Entra ID)

| ID | Pri | Requirement | AC |
|---|---|---|---|
| R3.1 | P0 | `module.access` using the `Twingate/twingate` provider: `twingate_remote_network`, `twingate_connector`, `twingate_connector_tokens` | Remote network and connector show healthy in the Twingate admin console after apply |
| R3.2 | P0 | Connector VM (Ubuntu LTS, small SKU) in `hub-access`, **no public IP**, installed via cloud-init, SSH key auth with public key supplied as a variable | `terraform test` T5 passes; connector reports Online |
| R3.3 | P0 | Link `privatelink.blob.core.windows.net` zone to hub and spoke2 VNets | From the connector, `nslookup <acct>.blob.core.windows.net` returns the 10.1.1.x private IP |
| R3.4 | P0 | Narrow NSG allows: connector subnet -> spoke-workload (22, 443); outbound from `hub-access` to spoke-workload and the PE subnet (443) | Rules reference exact prefixes and ports; T2/T3 pass; added to accepted-exceptions table |
| R3.5 | P0 | Twingate Resources: (a) test VM SSH, (b) test VM HTTPS, (c) storage blob FQDN:443 | Each resource appears in the console with correct address and ports |
| R3.6 | P0 | Two Entra-synced groups with different policies: `zt-developers` (a, b, c) and `zt-auditors` (c only) | Live demo: developer reaches all three; auditor reaches (c) only and is denied (a) and (b) |
| R3.7 | P1 | Twingate API key and network name as **sensitive HCP workspace variables**; connector tokens marked sensitive; outputs sensitive | `terraform output` never prints secrets; no secret in the repo or CI logs |
| R3.8 | P1 | Runbook `docs/RUNBOOK-twingate.md`: Entra IdP integration steps (console, not Terraform), group sync, client install, troubleshooting (DNS, connector offline) | A fresh reader can reproduce the setup |
| R3.9 | P2 | Decision on Bastion: documented as not deployed, or deployed behind a flag as break-glass | ADR-004 |

Known trade-off for this phase (documented, fixed in Phase 4): the connector token reaches the VM via cloud-init `custom_data`, so it exists in Terraform state and VM metadata. State is in HCP Terraform (encrypted, access-controlled). Phase 4 replaces this with a Key Vault fetch via managed identity.

### 7.5 Phase 4: Workloads and data-plane identity

| ID | Pri | Requirement | AC |
|---|---|---|---|
| R4.1 | P0 | `module.compute`: VM 1 in `spoke-workload`, VM 2 in `spoke2-workload`; no public IPs; system-assigned managed identities; SSH keys by public key only | `deploy_test_vms` toggles both; T5 passes |
| R4.2 | P0 | VM 1 serves HTTPS on 443 (self-signed cert, `python3` + `openssl` already on the image). **No `apt install` in cloud-init**, because default-deny outbound blocks package mirrors | VM 2 can `curl -k https://<vm1>` (F1); any other port fails |
| R4.3 | P0 | Storage `shared_access_key_enabled = false`; provider `storage_use_azuread = true` so Terraform can still manage containers over the data plane (or manage them via an alternative the module documents) | Apply succeeds; `az storage blob list --auth-mode key` fails; `--auth-mode login` works from an authorized path |
| R4.4 | P0 | RBAC: VM 1 identity gets `Storage Blob Data Reader` on the account; developers get reader (or contributor) via group | VM 1 reads a seeded blob using its managed identity (token from IMDS), no key or SAS |
| R4.5 | P0 | `module.keyvault`: RBAC authorization, public access off, purge protection and soft delete on, private endpoint in `spoke-private-endpoints`, `privatelink.vaultcore.azure.net` zone linked to hub/spoke/spoke2 | Secret retrievable only via private path; public access attempt fails |
| R4.6 | P0 | Move Twingate connector token to Key Vault; connector VM fetches it at boot via managed identity and F4 | Token absent from `custom_data` and from state beyond the Key Vault secret resource itself; connector still comes online |
| R4.7 | P0 | `scripts/verify-connectivity.sh`: runs the test matrix (section 8) using `az vm run-command invoke` so it works without any network path into the VMs; exits non-zero on any mismatch | Single command prints a PASS/FAIL table; run in README as a screenshot or snippet |
| R4.8 | P1 | Seed blob created without opening a public path (via Terraform data plane or the connector) | Documented method |
| R4.9 | P2 | Move `verify-connectivity.sh` into a manual GitHub Actions workflow (workflow_dispatch) using OIDC | Run produces the table as a job summary |

### 7.6 Phase 5: Observability

| ID | Pri | Requirement | AC |
|---|---|---|---|
| R5.1 | P0 | `module.monitoring`: Log Analytics workspace with a short retention and a **daily ingestion cap** | Workspace exists; cap visible; monthly ingestion expected inside the free allowance at this scale (verify in pricing calculator) |
| R5.2 | P0 | **VNet flow logs** (not NSG flow logs) on hub, spoke, spoke2, sent to a **dedicated** storage account and Log Analytics (Traffic Analytics optional) | Flow log resources show Enabled in Network Watcher |
| R5.3 | P0 | Diagnostic settings: Key Vault (audit events), storage (blob read/write/delete), NSG events, later Firewall | Records appear in the workspace |
| R5.4 | P0 | Saved KQL queries in `docs/kql/`: denied flows by source, flows from the connector subnet, Key Vault access by identity, failed storage auth | Each query returns data after the verify script runs |
| R5.5 | P1 | Defender for Cloud free-tier recommendations reviewed; findings documented as accepted/fixed | `docs/SECURITY-POSTURE.md` lists findings and decisions |
| R5.6 | P1 | Alert rule (e.g. spike of denied flows or Key Vault failed auth) emailing the maintainer | Alert fires in a test run |

Important platform facts (verified in this repo's planning): **creation of new NSG flow logs has been blocked since June 30, 2025, and NSG flow logs retire on September 30, 2027.** Use VNet flow logs. The flow log destination storage account must not be locked to selected networks, so it **cannot be the private-only account** from `module.storage`; use a separate account and document why.

### 7.7 Phase 6: Hub inspection (Azure Firewall)

Build this after Phases 4 and 5 so the new path can be tested with real VMs and observed in real logs.

| ID | Pri | Requirement | AC |
|---|---|---|---|
| R6.1 | P0 | Azure Firewall (Basic SKU) in `AzureFirewallSubnet` plus management subnet and public IPs, gated by `deploy_firewall` | Firewall provisions; diag logs flow to Log Analytics |
| R6.2 | P0 | Firewall policy: network rule spoke2-workload -> spoke-workload TCP/443 (F1); application rules for connector FQDNs (F5) | Rules named, ordered, and documented |
| R6.3 | P0 | Route tables with UDRs: `0.0.0.0/0` and inter-spoke prefixes next hop = firewall, attached to workload and `hub-access` subnets | T6 passes; effective routes verified on VM NICs |
| R6.4 | P0 | Set `enable_direct_spoke_peering = false`; F1 continues to work through the firewall | `verify-connectivity.sh` F1 passes; firewall log shows the allowed flow; direct peering resources are gone |
| R6.5 | P0 | Replace the temporary NAT/Internet-443 rule: remove `Internet` allow from `hub-access` NSG; connector egress only via firewall FQDN allow-list | Connector stays Online; any non-listed destination is denied and logged |
| R6.6 | P1 | **Build the FQDN allow-list from firewall deny logs**, not from guesses (Twingate endpoints, its package repo, OS mirrors); record the final list and how it was derived | `docs/EGRESS-ALLOWLIST.md` |
| R6.7 | P1 | Revisit NSG source/destination prefixes for F1/F2 after the path change (source address seen at spoke1 may differ) | Matrix still passes with prefixes as narrow as possible |
| R6.8 | P1 | Cost guard: `make down` removes the firewall; a note in README states list price per hour and that it is not left running | README "Cost" section |

### 7.8 Phase 7: Stretch (pick at most one)

| ID | Option |
|---|---|
| R7.1 | Multi-environment (dev/staging) via workspaces or tfvars with module-version promotion |
| R7.2 | Private DNS Resolver and additional private endpoints (SQL, ACR) |
| R7.3 | Container Apps or AKS in a spoke with network policies as a second microsegmentation layer |

## 8. Verification matrix

`scripts/verify-connectivity.sh` runs each row and compares to the expected result. Negative rows are as important as positive ones.

| # | From | To | Port | Expected | Evidence |
|---|---|---|---|---|---|
| V1 | VM 2 | VM 1 | 443 | allow | curl returns 200; firewall log (Phase 6) |
| V2 | VM 2 | VM 1 | 22 | **deny** | timeout; flow log denied record |
| V3 | VM 2 | VM 1 | 80 | **deny** | timeout; flow log |
| V4 | VM 1 | VM 2 | any | **deny** | timeout; flow log |
| V5 | VM 1 | internet | 443 | **deny** | timeout; flow log / firewall deny |
| V6 | VM 1 | storage | 443 | allow (managed identity) | blob read succeeds |
| V7 | VM 2 | storage | 443 | **deny** | timeout or 403 |
| V8 | VM 1 | storage with shared key | n/a | **deny** | `KeyBasedAuthenticationNotPermitted` |
| V9 | connector | VM 1 | 22, 443 | allow | nc/curl succeeds |
| V10 | connector | VM 2 | any | **deny** | timeout |
| V11 | connector | storage FQDN | 443 | resolves to 10.1.1.x and connects | `nslookup` + curl |
| V12 | laptop as developer | VM 1 SSH, VM 1 HTTPS, storage | via Twingate | allow | manual demo |
| V13 | laptop as auditor | storage | via Twingate | allow | manual demo |
| V14 | laptop as auditor | VM 1 SSH | via Twingate | **deny** | manual demo |
| V15 | anyone | any resource from the public internet | any | **deny** | no public IPs; storage public access disabled |

Rows V12 to V14 are manual (they need a Twingate client) and are captured as a short screen recording or screenshots in the README.

## 9. Security model

### 9.1 Threat model (seed for `docs/THREAT-MODEL.md`)

| Threat | Control | Where | Verified by |
|---|---|---|---|
| Lateral movement between workloads | Per-subnet default-deny NSGs, single documented flow | `modules/network` | T1, V2-V5 |
| Public exposure of data | Storage public access off, private endpoint, policy deny | `modules/storage`, `modules/policy` | T4, V15 |
| Secret/key theft | Shared keys disabled, managed identities, Key Vault via RBAC and private endpoint | `modules/storage`, `modules/keyvault` | V6, V8 |
| Unauthorized remote access | Identity-based ZTNA, no inbound ports, no public IPs, group-scoped resources | `modules/access` | V12-V14, T5 |
| Config drift / insecure PR | CI scanning, tests, policy deny | `.github/workflows/ci.yml` | R1.1-R1.3 |
| Undetected attack | VNet flow logs, diagnostics, saved queries, alert | `modules/monitoring` | R5.4, R5.6 |
| Data exfiltration via egress | Egress only through Firewall FQDN allow-list | `modules/egress` | V5, R6.5 |
| Compromised CI credentials | OIDC, no long-lived secrets, plan-only on PR | HCP + `scripts/setup-oidc.rb` | review |

### 9.2 Accepted exceptions register

The README table mirrors the flow register (6.4) plus these non-flow exceptions: PE subnet without an NSG (private-link traffic), flow-log storage account not locked to a VNet (platform requirement), temporary Internet:443 egress from `hub-access` (Phases 2-5, removed in Phase 6).

## 10. Cost model and guardrails

Estimates are list-price orders of magnitude for East US; **verify in the Azure pricing calculator before relying on them**.

| Component | Approx. when running | Policy |
|---|---|---|
| Azure Firewall Basic (+ management IP) | roughly $300/month if left on (about $0.40/hour) | Off by default; demo only |
| NAT Gateway + public IP | roughly $35-40/month plus data | Off by default |
| 3 small Linux VMs (connector + 2 test) | single-digit dollars each per month on the smallest burstable size, less if deallocated | Off by default; deallocate when idle |
| Log Analytics / flow logs | small at this scale; ingestion cap set | Daily cap, short retention |
| Key Vault, private endpoints | private endpoints bill hourly plus data; modest | Keep minimal count |

Guardrails: all costly components behind flags (6.3); `make up` / `make down` targets; a budget alert at the subscription or resource group; README lists the destroy command; after `make down`, `az resource list -g zt-rg` must return only the always-on baseline.

## 11. Module versioning and release

- Semver. v1.1.0 for the three existing modules (additive, defaults keep current behavior); v0.1.0 for new modules.
- Publish with `scripts/publish-module.sh`, then bump the `version` pins in `envs/dev/main.tf`. Never reference a module by relative path from `envs/dev`.
- A module change and its `.tftest.hcl` land in the same PR.
- Tag releases `vX.Y.Z` per phase completion; the GitHub release notes become the changelog.

## 12. Success metrics

**Leading (visible within each phase):**
- CI green/red behavior matches expectation (G1) and runtime < 5 min.
- 8 of 8 invariants (T1-T8) passing offline.
- Verification matrix: 100% of rows match expectation.

**Lagging (portfolio outcome):**
- README answers the five questions a reviewer asks within two minutes: what is it, how is it secured, how do I know, what does it cost, how do I tear it down.
- A 3 to 5 minute demo (matrix run, Twingate role difference, a denied packet found in KQL) can be given without preparation.
- Resume bullets (see ROADMAP.md) are each backed by a file or a screenshot in the repo.

## 13. Planned ADRs

| ADR | Decision |
|---|---|
| 001 | VNet flow logs instead of NSG flow logs (retirement dates above) |
| 002 | Direct spoke peering retained until Firewall path is verified, then removed |
| 003 | Connector token handling: cloud-init first, Key Vault fetch later |
| 004 | Twingate instead of Bastion; Bastion not deployed (or break-glass behind a flag) |
| 005 | Flow-log storage separate from the private-only data account |
| 006 | NAT Gateway as interim egress, Firewall FQDN rules as target |
| 007 | Azure Firewall Basic SKU and why |

## 14. Open questions

| # | Question | Blocking? | Owner |
|---|---|---|---|
| Q1 | Current Twingate free-plan limits (users, resources, connectors, remote networks) and whether Entra group sync is included | Yes, before Phase 3 | Akshay (check Twingate pricing/docs) |
| Q2 | Does an Entra tenant with the needed admin rights exist for the IdP integration and test users/groups? | Yes, before Phase 3 | Akshay |
| Q3 | Current Twingate connector egress requirements (FQDNs/ports) and install method | No, discovered in Phase 6 from logs | Akshay |
| Q4 | Does the NIC public-IP policy affect Firewall/NAT public IPs? | No | Akshay (test in Phase 2/6) |
| Q5 | How does `run-command` and the guest agent behave under DenyAllOutbound at 4096 (platform address 168.63.129.16)? | Yes, before Phase 4 verify script | Akshay (test early) |
| Q6 | Does the `azurerm` 4.81.0 `network_watcher_flow_log` resource support VNet targets, or is `azapi` needed? | No | Akshay (check provider docs in Phase 5) |
| Q7 | Budget ceiling for demos and the alert threshold | No | Akshay |
| Q8 | Is Checkov or Trivy the preferred scanner? | No | Akshay (default: Checkov, switch if noisy) |

## 15. Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Private DNS not linked to hub, so connector resolves public IP | High | Phase 3 blocked | R3.3 first; test with `nslookup` before anything else |
| Default-deny outbound breaks cloud-init (package installs) | High | VMs misconfigured | R4.2: no installs; use images' preinstalled tools; Phase 6 allow-list from logs |
| Firewall left running | Medium | Real money | Flags, `make down`, budget alert |
| Mocked-provider tests give false confidence | Medium | Missed regressions | Keep one real `plan` in CI via HCP speculative plan (R1.4) |
| Scanner noise causes skip-everything habit | Medium | Weak CI | R1.2 requires justification per skip |
| Twingate plan limits | Low-Medium | Rescope Phase 3 | Q1 early; fallback is documenting the design with a minimal resource set |
| Shared-key disablement breaks Terraform container management | Medium | Apply failures | R4.3 `storage_use_azuread` and documented fallback |

## 16. Definition of done (whole project)

- All P0 requirements across Phases 0 to 6 met; P1 either met or listed as consciously deferred.
- `make up` -> `verify-connectivity.sh` all PASS -> `make down` leaves no billable extras.
- README, THREAT-MODEL, RUNBOOK, ADRs, KQL, and diagrams (topology, access flow, observability) are current.
- Each resume bullet maps to a file path or screenshot in the repo.
