# Architecture

## Goals

1. A hub-and-spoke network fabric that is default-deny by construction.
2. Workloads that are private by default — no public data-plane endpoints.
3. Guardrails that keep the environment from drifting back to public exposure.

## Module graph

```
envs/dev
├── azurerm_resource_group.this
├── module.network   ── provides spoke VNet + private-endpoints subnet
├── module.storage   ── consumes the subnet and the spoke VNet
└── module.deny_public_ip_on_nic ── scoped to the resource group
```

`module.storage` depends on `module.network` for two inputs:

- `pe_subnet_id` — where the endpoint's NIC is allocated
- `vnet_id` — the network whose private DNS zone link resolves the endpoint

`module.deny_public_ip_on_nic` depends only on the resource group (its scope).

## Modules

### `modules/network`

Owns the fabric. Creates the hub and spoke VNets, the three subnets, the
default-deny NSGs and their subnet associations, and the bidirectional VNet
peering. The private-endpoints subnet is deliberately left without an NSG so
private-link traffic is not dropped before it reaches an endpoint.

The two NSGs are generated from one `deny_all_rules` map so inbound and
outbound rules can never drift between them.

### `modules/storage`

Owns the private data plane. Creates the storage account, the
`privatelink.blob.core.windows.net` private DNS zone and its VNet link, and
the blob private endpoint with a DNS zone group.

The storage account is hardened: StorageV2, TLS 1.2 minimum, HTTPS-only,
public network access disabled, nested (public) blob access disallowed, and
soft delete enabled for both blobs and containers.

The endpoint's private IP is exported from the private service connection
(`private_service_connection[0].private_ip_address`). `custom_dns_configs` is
intentionally *not* used: it is empty once a DNS zone group is attached.

### `modules/policy`

A thin, reusable wrapper over `azurerm_resource_group_policy_assignment`.
Takes a definition/initiative ID and an `enforce` toggle; the environment
supplies the built-in "Network interfaces should not have public IPs"
definition (`83a86a26-fd1f-447c-b59d-e51f44264114`).

## Naming and tagging

All physical names live in `envs/dev/locals.tf`, split into a `network_naming`
and a `storage_naming` object that are passed straight into the modules. This
keeps names out of resource bodies and makes renames a one-line change.
Common tags (`managed-by`, `project`, `environment`) are defined once and
passed to every module; `var.tags` is merged on top.

## State

State lives in HCP Terraform. Local state files and saved plans are
git-ignored; the provider dependency lock file is committed so every run
resolves identical provider versions.
