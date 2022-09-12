# Microservice Application distributed across AWS and Azure
# Configuration: 3

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

# Create resource group and associated query to group resources
resource "aws_resourcegroups_group" "rg_aws" {
  name = "masterarbeit_kleinhapl"

    resource_query {
    query = <<JSON
{
  "ResourceTypeFilters": [
    "AWS::AllSupported"
  ],
  "TagFilters": [
    {
      "Key": "rg",
      "Values": ["kleinhapl"]
    }
  ]
}
JSON
  }
}

# ------------------------NETWORK------------------------
# Isolated private network for ECS resources, it can also be configured using AWS default network, 
#however, creating a new network will avoid opening ports to the default network, which might contain other resources
# vpn defition
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
}

# internet gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

# subnet 1
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block = "10.0.0.0/24"
  map_public_ip_on_launch = true
  availability_zone = "eu-central-1a"
}

# subnet 2, additional subnet with a different availability zone is necessary for a db-subnet-group
resource "aws_subnet" "subnet2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "eu-central-1b"
}

# routing table for vpc
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
}

# add route to internet gateway
resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

# route to subnet1
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# route to subnet2
resource "aws_route_table_association" "subnet2" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.public.id
}

# ------------------------SECURITY GROUP------------------------
# security group that allows public access on db port and http for frontend
resource "aws_security_group" "aws_sec_group" {
  name        = "MA-Kleinhapl"
  description = "access on db, https and http port"
  vpc_id = aws_vpc.main.id

  # incoming: allow all on port 3306
  ingress {
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # incoming: allow all on port 80
  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # incoming: allow all on port 443
  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  #outgoing: allow all
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    "rg" = "kleinhapl"
  }
}

# ------------------------DATABASE------------------------
# subnet for the db so it can be in same vpc as security group
resource "aws_db_subnet_group" "db_subnet" {
  name       = "inventoria-db-subnet"
  subnet_ids = [aws_subnet.public.id, aws_subnet.subnet2.id]

  tags = {
    "rg" = "kleinhapl"
  }
}

resource "aws_db_instance" "db" {
  allocated_storage    = 5
  engine               = "mariadb"
  engine_version       = "10.3" # aws rds describe-db-engine-versions --engine mariadb  
  instance_class       = "db.t2.micro" # "db.t4g.micro"
  name                 = "inventoriadb"
  identifier           = "inventoriadb"
  username             = var.db_user
  password             = var.db_passwd
  skip_final_snapshot  = true # will not create a snapshot of DB when instance id deleted
  # final_snapshot_identifier = "inventoria_backup"
  publicly_accessible  = true
  vpc_security_group_ids = [aws_security_group.aws_sec_group.id]
  db_subnet_group_name = aws_db_subnet_group.db_subnet.name

  # Tag for resource group
  tags = {
    "rg" = "kleinhapl"
  }

  # will run a shell command before the resource is destroyed
  # import db backup
  provisioner "local-exec" {
    command = "../db_backup.sh"
  }

  # will execute a command locally when the resource is destroyed
  provisioner "local-exec" {
    when = destroy
    command = "mysqldump -h inventoriadb.cccqkewazeyi.eu-central-1.rds.amazonaws.com -u tom -pPa55w.rd inventoriadb > ../../backup/db/backup.sql"
  }
  depends_on = [
    aws_route_table.public,
    aws_route.public,
    aws_route_table_association.public
  ]
}

# ------------------------STORAGE------------------------
resource "aws_s3_bucket" "storage" {
  bucket = "inventoriastorage"
  force_destroy = true # allow deletion of non empty bucket

  # will run a shell command before the resource is destroyed
  # downloads all images the local backup directory
  provisioner "local-exec" {
    when = destroy
    command = "aws s3 sync s3://inventoriastorage/ ../../backup/images"
  }
}

resource "aws_s3_bucket_acl" "bucket_acl" {
  bucket = aws_s3_bucket.storage.id
  acl    = "public-read-write"

  # will run a shell command after the resource is deployed
  # uploads image data saved in the backup folder to the S3 bucket
  provisioner "local-exec" {
    command = "aws s3 sync ../../backup/images/ s3://inventoriastorage/"
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
    "DB_ENDPOINT" = aws_db_instance.db.endpoint
    "STORAGE_ACCOUNT_NAME" = var.aws_iam_id
    "STORAGE_ACCESS_KEY" = var.aws_iam_key
    "STORAGE_CONTAINER" = aws_s3_bucket.storage.bucket
    "STORAGE_PROVIDER" = "AWS" # "AZURE" or "AWS"
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
  value = aws_db_instance.db.endpoint
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
  value = aws_s3_bucket.storage.bucket
  description = "storage name"
}