data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}

#################################################################################################################
# LOCALS
#################################################################################################################

locals {
  vnet_cidr                   = ["10.10.0.0/24"]
  vm_subnet_cidr              = ["10.10.0.0/26"]
  fw_subnet_cidr              = ["10.10.0.64/26"]
  agw_ip_config_name          = "ipc-agwy-${var.prefix}"
  agw_frontend_port           = "port-http-${var.prefix}"
  agw_frontend_ip_config_name = "feipc-agwy-${var.prefix}"
  agw_listener_name           = "agwy-listener-${var.prefix}"
  agw_backend_pool            = "aks-backend-${var.prefix}"
  agw_backend_settings        = "http-settings-${var.prefix}"

}

#################################################################################################################
# RESOURCE GROUP
#################################################################################################################

resource "azurerm_resource_group" "public" {
  location = var.location
  name     = "rg-aks-agwy-${var.prefix}"
  tags     = var.tags
}

#################################################################################################################
# VNET AND SUBNET
#################################################################################################################

resource "azurerm_virtual_network" "public" {
  name                = "vnet-${var.prefix}"
  address_space       = local.vnet_cidr
  location            = azurerm_resource_group.public.location
  resource_group_name = azurerm_resource_group.public.name
}

resource "azurerm_subnet" "agwy" {
  name                 = "snet-agwy-${var.prefix}"
  resource_group_name  = azurerm_resource_group.public.name
  virtual_network_name = azurerm_virtual_network.public.name
  address_prefixes     = local.vm_subnet_cidr
}

resource "azurerm_subnet" "aks" {
  name                 = "snet-aks-${var.prefix}"
  resource_group_name  = azurerm_resource_group.public.name
  virtual_network_name = azurerm_virtual_network.public.name
  address_prefixes     = local.fw_subnet_cidr
}

#################################################################################################################
# AKS
#################################################################################################################

resource "azurerm_user_assigned_identity" "aks" {
  name                = "agic-identity"
  resource_group_name = azurerm_resource_group.public.name
  location            = azurerm_resource_group.public.location
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-${var.prefix}"
  location            = azurerm_resource_group.public.location
  resource_group_name = azurerm_resource_group.public.name
  dns_prefix          = "aks-${var.prefix}"

  default_node_pool {
    name           = "default"
    node_count     = 2
    vm_size        = "Standard_DS2_v2"
    vnet_subnet_id = azurerm_subnet.aks.id
    type           = "VirtualMachineScaleSets"

    upgrade_settings {
      drain_timeout_in_minutes      = 0
      max_surge                     = "10%"
      node_soak_duration_in_minutes = 0
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  ingress_application_gateway {
    gateway_id = azurerm_application_gateway.main.id
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
    outbound_type     = "loadBalancer"
  }
}

#################################################################################################################
# RBAC
#################################################################################################################

resource "azurerm_role_assignment" "rg_aks_ingress_reader" {
  scope                = azurerm_resource_group.public.id
  role_definition_name = "Reader"
  principal_id         = azurerm_kubernetes_cluster.aks.ingress_application_gateway[0].ingress_application_gateway_identity[0].object_id
}

resource "azurerm_role_assignment" "rg_nodes_ingress_reader" {
  scope                = azurerm_kubernetes_cluster.aks.node_resource_group_id
  role_definition_name = "Reader"
  principal_id         = azurerm_kubernetes_cluster.aks.ingress_application_gateway[0].ingress_application_gateway_identity[0].object_id
}

resource "azurerm_role_assignment" "agwy_ingress_contributor" {
  scope                = azurerm_application_gateway.main.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks.ingress_application_gateway[0].ingress_application_gateway_identity[0].object_id
}

resource "azurerm_role_assignment" "snet_agwy_ingress_contributor" {
  scope                = azurerm_subnet.agwy.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks.ingress_application_gateway[0].ingress_application_gateway_identity[0].object_id
}

#################################################################################################################
# APP GATEWAY
#################################################################################################################

resource "azurerm_public_ip" "agwy" {
  name                = "pip-agwy-${var.prefix}"
  resource_group_name = azurerm_resource_group.public.name
  location            = azurerm_resource_group.public.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_application_gateway" "main" {
  name                = "agwy-${var.prefix}"
  location            = azurerm_resource_group.public.location
  resource_group_name = azurerm_resource_group.public.name

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 2
  }

  waf_configuration {
    enabled          = true
    firewall_mode    = "Prevention"
    rule_set_type    = "OWASP"
    rule_set_version = "3.2"
  }

  gateway_ip_configuration {
    name      = local.agw_ip_config_name
    subnet_id = azurerm_subnet.agwy.id
  }

  frontend_port {
    name = local.agw_frontend_port
    port = 80
  }

  frontend_ip_configuration {
    name                 = local.agw_frontend_ip_config_name
    public_ip_address_id = azurerm_public_ip.agwy.id
  }

  backend_address_pool {
    name = local.agw_backend_pool
  }

  http_listener {
    name                           = local.agw_listener_name
    frontend_ip_configuration_name = local.agw_frontend_ip_config_name
    frontend_port_name             = local.agw_frontend_port
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "http-rule-${var.prefix}"
    rule_type                  = "Basic"
    http_listener_name         = local.agw_listener_name
    backend_address_pool_name  = local.agw_backend_pool
    backend_http_settings_name = local.agw_backend_settings
    priority                   = 10
  }

  backend_http_settings {
    name                  = local.agw_backend_settings
    port                  = 80
    protocol              = "Http"
    cookie_based_affinity = "Disabled"
    request_timeout       = 20
  }

  lifecycle {
    ignore_changes = [
      tags,
      backend_address_pool,
      backend_http_settings,
      http_listener,
      probe,
      request_routing_rule,
      frontend_port,
      redirect_configuration,
      ssl_certificate
    ]
  }
}

##########################################################################
# KEYVAULT
##########################################################################

resource "azurerm_key_vault" "public" {
  name                        = "kv-aks-${var.prefix}"
  location                    = azurerm_resource_group.public.location
  resource_group_name         = azurerm_resource_group.public.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  enable_rbac_authorization   = true
  sku_name                    = "standard"
}

##########################################################################
# RBAC KEYVAULT
##########################################################################

resource "azurerm_role_assignment" "kv_cli_rbac" {
  scope                = azurerm_key_vault.public.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "kv_azure_portal_rbac" {
  scope                = azurerm_key_vault.public.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = "89ab0b10-1214-4c8f-878c-18c3544bb547"
}

resource "azurerm_role_assignment" "kv_aks_reader" {
  scope                = azurerm_key_vault.public.id
  role_definition_name = "Key Vault Certificate User"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

##########################################################################
# SECRETS
##########################################################################

resource "azurerm_key_vault_certificate" "imported" {
  name         = "razumovsky-certificate"
  key_vault_id = azurerm_key_vault.public.id

  certificate {
    contents = filebase64("${path.root}/wildcard_22_Aug_2025_razumovsky.me.pfx")
    password = file("${path.root}/password.txt")
  }

  depends_on = [
    azurerm_role_assignment.kv_cli_rbac,
    azurerm_role_assignment.kv_azure_portal_rbac
  ]
}
