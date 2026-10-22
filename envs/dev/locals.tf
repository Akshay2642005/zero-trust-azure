locals {
  # Single source of truth for the resource group.
  resource_group_name = "zt-rg"

  # Names owned by the network module.
  network_naming = {
    hub_vnet                = "hub-vnet"
    spoke_vnet              = "spoke-vnet"
    spoke2_vnet             = "spoke2-vnet"
    hub_default_subnet      = "hub-default"
    hub_access_subnet       = "hub-access"
    spoke_workload_subnet   = "spoke-workload"
    spoke_pe_subnet         = "spoke-private-endpoints"
    spoke2_workload_subnet  = "spoke2-workload"
    hub_nsg                 = "hub-nsg"
    hub_access_nsg          = "hub-access-nsg"
    spoke_nsg               = "spoke-nsg"
    spoke2_nsg              = "spoke2-nsg"
    hub_to_spoke_peering    = "hub-to-spoke"
    spoke_to_hub_peering    = "spoke-to-hub"
    hub_to_spoke2_peering   = "hub-to-spoke2"
    spoke2_to_hub_peering   = "spoke2-to-hub"
    spoke_to_spoke2_peering = "spoke-to-spoke2"
    spoke2_to_spoke_peering = "spoke2-to-spoke"
  }

  # Names owned by the egress module.
  egress_naming = {
    nat_gateway   = "hub-access-nat"
    nat_public_ip = "hub-access-nat-ip"
  }

  # Names owned by the storage module.
  storage_naming = {
    storage_account            = var.storage_account_name
    private_dns_zone           = "privatelink.blob.core.windows.net"
    private_dns_zone_link      = "blob-vnet-link"
    private_endpoint           = "pe-storage-blob"
    private_service_connection = "pe-storage-blob-connection"
    private_dns_zone_group     = "storage-dns-zone-group"
  }

  # Azure Policy built-in "Network interfaces should not have public IPs".
  deny_public_ip_on_nic_name          = "deny-public-ip-on-nic"
  deny_public_ip_on_nic_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/83a86a26-fd1f-447c-b59d-e51f44264114"

  # Tags applied to every resource that supports them.
  common_tags = merge(
    {
      managed-by  = "terraform"
      project     = "zero-trust-network"
      environment = var.environment
    },
    var.tags,
  )

  # --- Phase 1 policy guardrails ---
  #
  # Built-in definition IDs were verified with `az policy definition list`.
  # The built-in storage policies default to Audit, so every Deny assignment
  # passes effect = Deny explicitly.

  deny_inbound_management_ports_rule = jsonencode({
    "if" = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.Network/networkSecurityGroups"
        },
        {
          count = {
            field = "Microsoft.Network/networkSecurityGroups/securityRules[*]"
            where = {
              allOf = [
                {
                  field  = "Microsoft.Network/networkSecurityGroups/securityRules[*].direction"
                  equals = "Inbound"
                },
                {
                  field  = "Microsoft.Network/networkSecurityGroups/securityRules[*].access"
                  equals = "Allow"
                },
                {
                  anyOf = [
                    {
                      field = "Microsoft.Network/networkSecurityGroups/securityRules[*].destinationPortRange"
                      in    = ["22", "3389"]
                    },
                    {
                      field = "Microsoft.Network/networkSecurityGroups/securityRules[*].destinationPortRanges[*]"
                      in    = ["22", "3389"]
                    },
                  ]
                },
                {
                  anyOf = [
                    {
                      field = "Microsoft.Network/networkSecurityGroups/securityRules[*].sourceAddressPrefix"
                      in    = ["*", "0.0.0.0/0", "Internet", "any"]
                    },
                    {
                      field = "Microsoft.Network/networkSecurityGroups/securityRules[*].sourceAddressPrefixes[*]"
                      in    = ["*", "0.0.0.0/0", "Internet", "any"]
                    },
                  ]
                },
              ]
            }
          }
          greater = 0
        },
      ]
    }
    "then" = {
      effect = "Deny"
    }
  })

  policy_assignments = {
    "deny-storage-public" = {
      definition_id     = "/providers/Microsoft.Authorization/policyDefinitions/b2982f36-99f2-4db5-8eff-283140c09693"
      custom_definition = null
      parameters        = { effect = { value = "Deny" } }
      display_name      = "Storage: disable public network access"
      description       = "Zero Trust: storage accounts are reachable only through private endpoints."
      enforce           = true
    }

    "deny-storage-https" = {
      definition_id     = "/providers/Microsoft.Authorization/policyDefinitions/404c3081-a854-4457-ae30-26a93ef643f9"
      custom_definition = null
      parameters        = { effect = { value = "Deny" } }
      display_name      = "Storage: require secure transfer"
      description       = "Zero Trust: reject storage accounts that allow plain HTTP."
      enforce           = true
    }

    "deny-storage-tls" = {
      definition_id     = "/providers/Microsoft.Authorization/policyDefinitions/fe83a0eb-a853-422d-aac2-1bffd182c5d0"
      custom_definition = null
      parameters = {
        minimumTlsVersion = { value = "TLS1_2" }
        effect            = { value = "Deny" }
      }
      display_name = "Storage: minimum TLS 1.2"
      description  = "Zero Trust: reject storage accounts that negotiate TLS below 1.2."
      enforce      = true
    }

    "deny-inbound-mgmt" = {
      definition_id = null
      custom_definition = {
        name         = "deny-inbound-management-ports"
        display_name = "NSG rules must not allow inbound SSH or RDP from the internet"
        description  = "Zero Trust: deny NSG rules that allow inbound TCP 22 or 3389 from a wildcard, Internet, or any source."
        mode         = "All"
        policy_rule  = local.deny_inbound_management_ports_rule
        metadata = jsonencode({
          category = "Network"
          source   = "zero-trust-azure"
          version  = "1.0.0"
        })
      }
      parameters   = null
      display_name = "NSG: no inbound SSH/RDP from the internet"
      description  = "Zero Trust: management ports are reachable only through identity-based access, not the public internet."
      enforce      = true
    }

    "audit-tag-managed-by" = {
      definition_id     = "/providers/Microsoft.Authorization/policyDefinitions/871b6d14-10aa-478d-b590-94f262ecfa99"
      custom_definition = null
      parameters        = { tagName = { value = "managed-by" } }
      display_name      = "Audit: managed-by tag required"
      description       = "Audit resources without the managed-by tag before switching this to Deny."
      enforce           = false
    }

    "audit-tag-project" = {
      definition_id     = "/providers/Microsoft.Authorization/policyDefinitions/871b6d14-10aa-478d-b590-94f262ecfa99"
      custom_definition = null
      parameters        = { tagName = { value = "project" } }
      display_name      = "Audit: project tag required"
      description       = "Audit resources without the project tag before switching this to Deny."
      enforce           = false
    }

    "audit-tag-env" = {
      definition_id     = "/providers/Microsoft.Authorization/policyDefinitions/871b6d14-10aa-478d-b590-94f262ecfa99"
      custom_definition = null
      parameters        = { tagName = { value = "environment" } }
      display_name      = "Audit: environment tag required"
      description       = "Audit resources without the environment tag before switching this to Deny."
      enforce           = false
    }
  }
}
