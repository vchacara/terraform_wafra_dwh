resource "azurerm_resource_group" "lab_1" {
  location = var.preferred_location
  name     = var.resource_group_name
}

resource "azurerm_data_factory" "data_factory_wdh_uat" {
  name                = "adf-dwh-eus-uat"
  location            = azurerm_resource_group.lab_1.location
  resource_group_name = azurerm_resource_group.lab_1.name
}

resource "azurerm_storage_account" "storage_sql_log" {
  name                     = "stsqldwhuateus01"
  resource_group_name      = azurerm_resource_group.lab_1.name
  location                 = azurerm_resource_group.lab_1.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_mssql_server" "sqlserver" {
  name = "sql-dwh-uat-eus-01"
  resource_group_name = azurerm_resource_group.lab_1.name
  location = azurerm_resource_group.lab_1.location
  version = "12.0"
  administrator_login = "wafra-admin"
  administrator_login_password = "Microsoft1@_2021$%"
  minimum_tls_version = "1.2"
  public_network_access_enabled = false


  azuread_administrator {
    login_username = "SVC Security Admin"
    object_id      = "538f5d38-a638-413a-b4ab-e45d587c9bc7"
  }

  identity{
    type = "SystemAssigned"
  }

  tags = {
    environment = "UAT"
  }
}

resource "azurerm_mssql_database" "sqlserverdb" {
  name = "DWH_UAT_1"
  server_id = azurerm_mssql_server.sqlserver.id
  sku_name = "GP_S_Gen5_1"
  min_capacity = 1
  auto_pause_delay_in_minutes = -1
  geo_backup_enabled = true

  long_term_retention_policy{
    weekly_retention  = "P7Y"
    monthly_retention = "P7Y"
    week_of_year = 1
  }

  short_term_retention_policy{
    retention_days = 35
  }

  tags = {
    environment = "UAT"
  }
}

resource "azurerm_mssql_server_extended_auditing_policy" "sqlauditpolicy" {
  server_id                               = azurerm_mssql_server.sqlserver.id
  storage_endpoint                        = azurerm_storage_account.storage_sql_log.primary_blob_endpoint
  storage_account_access_key              = azurerm_storage_account.storage_sql_log.primary_access_key
  storage_account_access_key_is_secondary = false
  retention_in_days                       = 6

  depends_on = [
    azurerm_storage_account.storage_sql_log,
  ]
}

resource "azurerm_virtual_network" "dbvnet" {
  name                = "VC-VNET-01"
  address_space       = ["10.4.0.0/24"]
  resource_group_name = "rg-vc-aa-us"
  location            = "eastus2"

  subnet {
    name           = "VSNEastUS-Databases"
    address_prefix = "10.4.0.16/28"
  }

  subnet {
    name           = "TEST"
    address_prefix = "10.4.0.0/28"
    security_group = "/subscriptions/ceb56d52-5419-431d-9453-6701a9c46fb6/resourceGroups/rg-vc-aa-us/providers/Microsoft.Network/networkSecurityGroups/VC-VNET-NSG-01"
  }

  subnet {
    name           = "AzureFirewallSubnet"
    address_prefix = "10.4.0.64/26"
  }
}

resource "azurerm_private_endpoint" "sqlprivatelink" {
  name                = "pl-sql-dwh-uat-eus-01"
  resource_group_name = azurerm_resource_group.lab_1.name
  location            = azurerm_virtual_network.dbvnet.location
  subnet_id           = "/subscriptions/ceb56d52-5419-431d-9453-6701a9c46fb6/resourceGroups/rg-vc-aa-us/providers/Microsoft.Network/virtualNetworks/VC-VNET-01/subnets/VSNEastUS-Databases"


  private_service_connection {
    name = "example-privateserviceconnection"
    private_connection_resource_id = azurerm_mssql_server.sqlserver.id
    subresource_names              = [ "sqlserver" ]
    is_manual_connection           = false
  }
}

# Network security group (NSG)
resource "azurerm_network_security_group" "nsg" {
  name                = "NSGVSNEUSUAT01"
  location            = azurerm_virtual_network.dbvnet.location
  resource_group_name = azurerm_resource_group.lab_1.name
}

resource "azurerm_subnet_network_security_group_association" "nsg_to_subnet" {
  subnet_id                 = "/subscriptions/ceb56d52-5419-431d-9453-6701a9c46fb6/resourceGroups/rg-vc-aa-us/providers/Microsoft.Network/virtualNetworks/VC-VNET-01/subnets/VSNEastUS-Databases"
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_app_service_plan" "appserviceplan" {
  name                = "asp-dwh-uat-eus-01"
  location            = azurerm_resource_group.lab_1.location
  resource_group_name = azurerm_resource_group.lab_1.name
  sku {
    tier = "PremiumV2"
    size = "P1v2"
  }
}
# Create the web app, pass in the App Service Plan ID, and deploy code from a public GitHub repo
resource "azurerm_app_service" "webapp" {
  name                = "app-dwhapi-uat-eus-01"
  location            = azurerm_resource_group.lab_1.location
  resource_group_name = azurerm_resource_group.lab_1.name
  app_service_plan_id = azurerm_app_service_plan.appserviceplan.id
  /*source_control {
    repo_url           = "https://github.com/Azure-Samples/nodejs-docs-hello-world"
    branch             = "master"
    manual_integration = true
    use_mercurial      = false
  }*/
}