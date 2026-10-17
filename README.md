# Zero-Trust Azure Network (Terraform)

A production-oriented, hub-and-spoke network on Azure: a default-deny network
fabric, a private-only storage workload reachable solely through a private
endpoint, and a control-plane guardrail that blocks public IPs on network
interfaces.

The configuration is split into reusable modules with a single environment
root, so the same fabric can be deployed to any number of environments.

## Architecture

```
                   ┌──────────────────────────────────────────────┐
                   │                Resource group: zt-rg          │
                   │                                              │
   hub-vnet  ◄─────┼── bidirectional VNet peering ──►  spoke-vnet │
   10.0.0.0/16     │                                    10.1.0.0/16│
                   │  hub-default       spoke-workload            │
                   │  10.0.1.0/24       10.1.0.0/24               │
                   │                    spoke-private-endpoints   │
                   │                    10.1.1.0/24               │
                   │                                              │
                   │  Default-deny NSGs on hub-default and        │
                   │  spoke-workload.                             │
                   │                                              │
                   │  ztstorage (public access disabled)          │
                   │      ▲                                       │
                   │      └── pe-storage-blob (private endpoint)  │
                   │              delegated into spoke-private-…  │
                   │              resolved via privatelink.blob…  │
                   │                                              │
                   │  Policy: deny public IPs on NICs (enforced)  │
                   └──────────────────────────────────────────────┘
```

## Repository layout

```
modules/
  network/   hub + spoke VNets, subnets, default-deny NSGs, VNet peering
  storage/   private storage account, blob private endpoint, private DNS zone
  policy/    resource-group policy assignment (guardrails)
envs/
  dev/       the dev environment root: providers, backend, variables,
             locals (naming + tags), module wiring and outputs
```

Each module is self-contained: it declares its own inputs and outputs, takes a
`naming` object so names live in one place, and tags everything it creates.

## What it creates

| Resource | Notes |
|----------|-------|
| Resource group | `zt-rg`, managed by Terraform |
| `hub-nsg`, `spoke-nsg` | default-deny inbound **and** outbound |
| `hub-vnet` (10.0.0.0/16) | hub network |
| `spoke-vnet` (10.1.0.0/16) | workload network |
| `hub-default`, `spoke-workload` | subnets with the NSGs associated |
| `spoke-private-endpoints` | open subnet reserved for private endpoints |
| bidirectional peering | forwarded traffic enabled |
| `ztstorage` | StorageV2, TLS 1.2+, HTTPS-only, public access disabled |
| `privatelink.blob.core.windows.net` | private DNS zone, linked to the spoke VNet |
| `pe-storage-blob` | private endpoint + DNS zone group |
| `deny-public-ip-on-nic` | Azure Policy assignment, enforced |

## Inputs

| Name | Description | Default |
|------|-------------|---------|
| `subscription_id` | Target Azure subscription | — |
| `location` | Azure region | `eastus` |
| `environment` | Environment name used in tags | `dev` |
| `storage_account_name` | Globally unique storage account name | — |
| `hub_address_space` | Hub VNet address space | `["10.0.0.0/16"]` |
| `spoke_address_space` | Spoke VNet address space | `["10.1.0.0/16"]` |
| `hub_default_subnet_prefix` | Hub default subnet | `10.0.1.0/24` |
| `spoke_workload_subnet_prefix` | Spoke workload subnet | `10.1.0.0/24` |
| `spoke_pe_subnet_prefix` | Spoke private-endpoints subnet | `10.1.1.0/24` |
| `allow_forwarded_traffic` | Allow forwarded traffic across peerings | `true` |
| `tags` | Extra tags merged into the common tags | `{}` |

## Outputs

| Name | Description |
|------|-------------|
| `resource_group_name` | Resource group name |
| `hub_vnet_id` | Hub VNet resource ID |
| `spoke_vnet_id` | Spoke VNet resource ID |
| `storage_account_name` | Storage account name |
| `storage_private_endpoint_id` | Blob private endpoint resource ID |
| `storage_private_endpoint_ip` | Private IP allocated to the endpoint |
| `policy_assignment_id` | Deny-public-IP-on-NIC assignment ID |

## Usage

State is held in HCP Terraform (Terraform Cloud). See `envs/dev/backend.tf`
for the workspace configuration.

```bash
# One-time
terraform login
# edit envs/dev/backend.tf -> set your organization, then:
make init

# Per change
make fmt        # terraform fmt -recursive
make validate
make plan
make apply
make destroy
```

Copy `envs/dev/terraform.tfvars.example` to `envs/dev/terraform.tfvars`
(git-ignored) and fill in `subscription_id` and `storage_account_name`.

## Security posture

- **Default deny** — both NSGs drop all inbound and outbound traffic unless a
  higher-priority rule allows it.
- **No public data plane** — the storage account has public network access
  disabled; it is reachable only through the private endpoint, and only from
  the peered network.
- **Private name resolution** — `privatelink.blob.core.windows.net` is linked
  to the spoke VNet so the storage FQDN resolves to the endpoint's private IP.
- **Guardrail** — the enforced `deny-public-ip-on-nic` policy rejects any NIC
  in the resource group that has a public IP, preventing drift away from the
  private design.

## Notes

- The private-endpoints subnet is intentionally left without an NSG so that
  private-link traffic is not dropped before it reaches the endpoint.
- The storage account name must be globally unique and match
  `^[a-z0-9]{3,24}$`; the variable validates this before any plan runs.
