# Microservice Application distributed across AWS and Azure
# Configuration: 4

# ------------------------Variables------------------------
variable "aws_region" {
  type        = string
  description = "Region to which the configuration will be deployed"
}

variable "azure_rg" {
  type        = string
  description = "Azure resource group to which to deploy resources"
}

variable "azure_region" {
  type        = string
  description = "Azure region group to which to deploy resources"
}

variable "db_user" {
  type        = string
  description = "DB username"
}

variable "db_passwd" {
  type        = string
  description = "DB password"
}

variable "custom_vision_url" {
  type        = string
  description = "Custom vision endpoint URL, leave empty to run without"
}

variable "custom_vision_key" {
  type        = string
  description = "custom vision api key"
}

variable "aws_iam_id" {
  type        = string
  description = "AWS IAM ID"
}

variable "aws_iam_key" {
  type        = string
  description = "AWS IAM key"
}

# ------------------------TERRAFORM CONFIG------------------------
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }

  }

  required_version = ">= 0.14.9"
}

# Profile needs to be configures in aws cli using aws configure
provider "aws" {
  profile = "default"
  region  = var.aws_region
}

provider "azurerm" {
  features{}
  skip_provider_registration = true
}

# ------------------------RESOURCE GROUPS------------------------
# Azure resource group
# Import existing resource group: terraform import azurerm_resource_group.rg_azure /Azure_Resource_ID
# Don't necessarily terraform to manage this resource, remove using: terraform state rm azurerm_resource_group.rg_azure
/*
resource "azurerm_resource_group" "rg_azure" {
    name     = var.azure_rg
    location = var.azure_region

  lifecycle {
    prevent_destroy = true
  }
} */


# ------------------------NETWORK------------------------
# Isolated private network for ECS resources, it can also be configured using AWS default network, 
# however, creating a new network will avoid opening ports to the default network, which might contain other resources
# not needed since the configuration is Azure only


# ------------------------SECURITY GROUP------------------------
# security group that allows public access on db port and http for frontend
# not needed since the configuration is Azure only

# ------------------------DATABASE------------------------
# subnet for the db so it can be in same vpc as security group
# db server
resource "azurerm_mariadb_server" "db_server" {
  name                = "inventoriadb"
  location            = var.azure_region
  resource_group_name = var.azure_rg

  administrator_login          = var.db_user
  administrator_login_password = var.db_passwd

  sku_name   = "B_Gen5_1"
  storage_mb = 5120
  version    = "10.3"

  auto_grow_enabled             = false
  geo_redundant_backup_enabled  = false
  public_network_access_enabled = true
  ssl_enforcement_enabled       = false
}

# db instance
resource "azurerm_mariadb_database" "db_instance" {
  name                = "inventoriadb"
  resource_group_name = var.azure_rg
  server_name         = azurerm_mariadb_server.db_server.name
  charset             = "utf8"
  collation           = "utf8_general_ci"

  # will run a shell command before the resource is destroyed
  # import db backup
  provisioner "local-exec" {
    command = "../db_backup.sh"
  }

  # will execute a command locally when the resource is destroyed
  # db data dump (needs to be done here because once the gateway is deleted there is no way to reach the db)
  provisioner "local-exec" {
    when = destroy
    command = "mysqldump -h inventoriadb.mariadb.database.azure.com -u tom -pPa55w.rd inventoriadb > ../../backup/db/backup.sql"
  }

  # to make sure db is accessible for local-exec
  depends_on = [
    azurerm_mariadb_firewall_rule.example
  ]
}

# db firewall rule to allow public access
resource "azurerm_mariadb_firewall_rule" "example" {
  name                = "public-access"
  resource_group_name = var.azure_rg
  server_name         = azurerm_mariadb_server.db_server.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "255.255.255.255"
}

# ------------------------STORAGE------------------------
resource "azurerm_storage_account" "storage" {
  name                     = "inventoriastorage"
  resource_group_name      = "masterarbeit_kleinhapl"
  location                 = var.azure_region
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "container" {
  name                  = "images"
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "container"

  # will execute a command locally before the resource is destroyed
  # db data dump (needs to be done here because once the gateway is deleted there is no way to reach the db)
  provisioner "local-exec" {
    when = destroy
    command = "az storage blob directory download -c images --account-name inventoriastorage -s '*' -d '../../backup/images/'"
  }

  # will run a shell command after the resource is deployed
  provisioner "local-exec" {
    command = "az storage blob directory upload -c images --account-name inventoriastorage -s '../../backup/images/*' -d '.'"
  }

}

# ------------------------FRONTEND------------------------
# server farm
  resource "azurerm_service_plan" "app_service_plan_frontend" {
  name                = "app-service-plan-frontend"
  resource_group_name = var.azure_rg
  location            = var.azure_region
  os_type             = "Linux"
  sku_name            = "B2"
}

# web app service
resource "azurerm_linux_web_app" "inventoria_frontend" {
  name                = "inventoria-frontend"
  resource_group_name = var.azure_rg
  location            = var.azure_region
  service_plan_id     = azurerm_service_plan.app_service_plan_frontend.id

  # container config
  site_config {
    application_stack {
      docker_image     = "tiemtom/masterarbeit-frontend"
      docker_image_tag = "latest"
    }
    cors {
      allowed_origins = ["*"]
    }
  }
}

# ------------------------BACKEND------------------------
# server farm
  resource "azurerm_service_plan" "app_service_plan_backend" {
  name                = "app-service-plan-backend"
  resource_group_name = var.azure_rg
  location            = var.azure_region
  os_type             = "Linux"
  sku_name            = "B2"
}

# web app service
resource "azurerm_linux_web_app" "inventoria_backend" {
  name                = "inventoria-backend"
  resource_group_name = var.azure_rg
  location            = var.azure_region
  service_plan_id     = azurerm_service_plan.app_service_plan_backend.id

  # container config
  site_config {
    application_stack {
      docker_image     = "tiemtom/masterarbeit-backend"
      docker_image_tag = "latest"
    }
    cors {
      allowed_origins = ["*"]
    }
  }

  # environment variables which can be accessed from code
  app_settings = {
    "DB_ENDPOINT" = azurerm_mariadb_server.db_server.fqdn
    "STORAGE_ACCOUNT_NAME" = azurerm_storage_account.storage.name
    "STORAGE_ACCESS_KEY" = azurerm_storage_account.storage.primary_access_key
    "STORAGE_CONTAINER" = azurerm_storage_container.container.name
    "STORAGE_PROVIDER" = "AZURE" # "AZURE" or "AWS"
    "CUSTOM_VISION_URL" = var.custom_vision_url
    "CUSTOM_VISION_KEY" = var.custom_vision_key
    "DB_USER" = var.db_user
    "DB_PASSWD" = var.db_passwd
    "AWS_REGION" = var.aws_region
    "BACKEND_URL" = "https://inventoria-backend.azurewebsites.net"
  }
}

# ------------------------OUTPUTS------------------------
# db endpoint
output "db_endpoint" {
  value = azurerm_mariadb_server.db_server.fqdn
  description = "db endpoint"
}

# frontend endpoint
output "frontend_endpoint" {
  value = azurerm_linux_web_app.inventoria_frontend.default_hostname
  description = "frontend enpoint"
}

# backend endpoint
output "backend_endpoint" {
  value = azurerm_linux_web_app.inventoria_backend.default_hostname
  description = "backend enpoint"
}

# storage name
output "stroage_name" {
  value = azurerm_storage_account.storage.name
  description = "storage name"
} 