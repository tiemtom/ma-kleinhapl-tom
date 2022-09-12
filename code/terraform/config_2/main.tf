# Microservice Application distributed across AWS and Azure
# Configuration: 2

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
  description = "Allow access on db port"
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

  # outgoing: allow all
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
resource "aws_s3_bucket" "storage" {
  bucket = "inventoriastorage"
  force_destroy = true # Will allow deletion of non empty bucket

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
  }
}

# ------------------------BACKEND------------------------
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

resource "aws_ecs_task_definition" "backend-container" {
  family = "inventoria-backend"
  requires_compatibilities = ["FARGATE"]
  network_mode = "awsvpc"
  cpu = 512
  memory = 1024
  execution_role_arn = "arn:aws:iam::964609114905:role/ecsTaskExecutionRole"
  container_definitions = jsonencode([
    {
      name      = "inventoria-backend"
      image     = "tiemtom/masterarbeit-backend"
      cpu       = 512
      memory    = 1024
      essential = true
      portMappings = [
        {
          containerPort = 80
        }
      ]
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group = "/ecs/inventoria-backend",
          awslogs-region = "eu-central-1",
          awslogs-stream-prefix = "ecs"
        }
      }
      
      environment = [
        {
          name = "DB_ENDPOINT"
          value = azurerm_mariadb_server.db_server.fqdn
        },
        {
          name = "STORAGE_ACCOUNT_NAME"
          value = var.aws_iam_id
        },
        {
          name = "STORAGE_ACCESS_KEY"
          value = var.aws_iam_key
        },
        {
          name = "STORAGE_CONTAINER"
          value = aws_s3_bucket.storage.bucket
        },
        {
          name = "STORAGE_PROVIDER"
          value = "AWS"
        },
        {
          name = "BACKEND_URL"
          value = aws_lb.lb.dns_name
        },
        {
          name = "AWS_REGION"
          value = var.aws_region
        },
        {
          name = "CUSTOM_VISION_KEY"
          value = var.custom_vision_key
        },
        {
          name = "CUSTOM_VISION_URL" # leave string empty if running without custom vision ("")
          value = var.custom_vision_url
        },
        {
          name = "DB_USER" # leave string empty if running without custom vision ("")
          value = var.db_user
        },
        {
          name = "DB_PASSWD" # leave string empty if running without custom vision ("")
          value = var.db_passwd
        },
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
resource "aws_ecs_service" "inventoria_backend" {
  name            = "inventoria-backend"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.backend-container.arn
  desired_count   = 1
  launch_type = "FARGATE"

  network_configuration {
    subnets = [aws_subnet.public.id] # Default Subnet
    security_groups = [aws_security_group.aws_sec_group.id]
    assign_public_ip = true # assign public ip to container on startup
  }

    load_balancer {
    target_group_arn = aws_lb_target_group.lb_group.arn
    container_name   = "inventoria-backend"
    container_port   = 80
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
  depends_on = [
    aws_lb.lb
  ]
  value = aws_lb.lb.dns_name
  description = "backend endpoint"
}