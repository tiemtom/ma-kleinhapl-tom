# Microservice Application distributed across AWS and Azure
# Configuration: 1

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
# Import existing resource group: terraform import azurerm_resource_group.rg_azure /subscriptions/c42c6aa8-3c10-40e5-a3ff-ba5843e3dda5/resourceGroups/Masterarbeit_Kleinhapl
# Don't necessarily terraform to manage this resource, remove using: terraform state rm azurerm_resource_group.rg_azure
/*
resource "azurerm_resource_group" "rg_azure" {
    name     = "masterarbeit_kleinhapl"
    location = "northeurope"

  lifecycle {
    prevent_destroy = true
  }
} */

# Create resource group and associated query to group resources
resource "aws_resourcegroups_group" "rg_aws" {
  name = "Masterarbeit_Kleinhapl"

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
  publicly_accessible  = true # need to look into peering with an azure vnet if its not too expensive
  # security group
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
resource "azurerm_storage_account" "storage" {
  name                     = "inventoriastorage"
  resource_group_name      = var.azure_rg
  location                 = var.azure_region
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "container" {
  name                  = "images"
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "container"

    # will execute a command locally before the resource is destroyed
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
# load balancer
resource "aws_lb" "lb" {
  name               = "MA-Kleinhapl"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.aws_sec_group.id]
  subnets            = [aws_subnet.public.id, aws_subnet.subnet2.id]

  tags = {
    "rg" = "kleinhapl"
  }
}

resource "aws_lb_target_group" "lb_group" {
  name     = "lg-tg-inventoria"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  target_type = "ip"

  depends_on = [aws_lb.lb]
}

# port 80 listener for lb
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_group.arn
  }
}
/*
# request certificate for lb
resource "aws_acm_certificate" "cert" {
  domain_name       = aws_lb.lb.dns_name
  validation_method = "DNS"

  tags = {
    "rg" = "kleinhapl"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# NEEDS A CERTIFICATE
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_group.arn
  }
}
*/

# task that will pull the container
resource "aws_ecs_task_definition" "frontend-container" {
  family = "inventoria-frontend"
  requires_compatibilities = ["FARGATE"]
  network_mode = "awsvpc"
  cpu = 512
  memory = 1024
  container_definitions = jsonencode([
    {
      name      = "inventoria-frontend"
      image     = "tiemtom/masterarbeit-frontend"
      cpu       = 512
      memory    = 1024
      essential = true
      portMappings = [
        {
          containerPort = 80
        }
      ]
    }
  ])
    runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
}

# cluster which will run the container instance
resource "aws_ecs_cluster" "cluster" {
  name = "MA-Kleinhapl"

  tags = {
    "rg" = "kleinhapl"
  }
}

resource "aws_ecs_cluster_capacity_providers" "provider-config" {
  cluster_name = aws_ecs_cluster.cluster.name

  capacity_providers = [ "FARGATE" ] # aws_ecs_capacity_provider.provider.name

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

# Start task as a ecs service
resource "aws_ecs_service" "inventoria_frontend" {
  name            = "inventoria-frontend"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.frontend-container.arn
  desired_count   = 1
  launch_type = "FARGATE"

  network_configuration {
    subnets = [aws_subnet.public.id] # Default Subnet
    security_groups = [aws_security_group.aws_sec_group.id]
    assign_public_ip = true # assign public ip to container on startup
  }

    load_balancer {
    target_group_arn = aws_lb_target_group.lb_group.arn
    container_name   = "inventoria-frontend"
    container_port   = 80
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
  }

  # environment variables which can be accessed from code
  app_settings = {
    "DB_ENDPOINT" = aws_db_instance.db.endpoint
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
  value = aws_db_instance.db.endpoint
  description = "db endpoint"
}

# backend endpoint
output "backend_endpoint" {
  value = azurerm_linux_web_app.inventoria_backend.default_hostname
  description = "backend enpoint"
}

# frontend endpoint 
output "frontend_endpoint" {
  depends_on = [
    aws_lb.lb
  ]
  value = aws_lb.lb.dns_name
  description = "frontend endpoint"
}

# storage 