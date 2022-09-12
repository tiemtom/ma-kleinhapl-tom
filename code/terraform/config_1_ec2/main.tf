# Config 1 deployment on ec2
# will deploy on default subnet
# This deployment is based on an early version of the application and cannot be deployed in its current state. It is archived here as a reference on how to do ecs deployment using ec2.

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
  region  = "eu-central-1"
}

provider "azurerm" {
  features{}
  skip_provider_registration = true
}

# Azure resource group
# Import existing resource group: terraform import azurerm_resource_group.rg_azure /subscriptions/c42c6aa8-3c10-40e5-a3ff-ba5843e3dda5/resourceGroups/Masterarbeit_Kleinhapl
# Don't want terraform to manage this resource, remove using: terraform state rm azurerm_resource_group.rg_azure

resource "azurerm_resource_group" "rg_azure" {
    name     = "masterarbeit_kleinhapl"
    location = "northeurope"
  lifecycle {
    prevent_destroy = true
  }
}

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

# DATABASE
resource "aws_db_instance" "db" {
  allocated_storage    = 5
  engine               = "mariadb"
  engine_version       = "10.6.7" # aws rds describe-db-engine-versions --engine mariadb  
  instance_class       = "db.t2.micro" # "db.t4g.micro"
  name                 = "inventoriadb"
  identifier           = "inventoriadb"
  username             = "tom"
  password             = "Pa55w.rd"
  skip_final_snapshot  = true # will not create a snapshot of DB when instance id deleted
  # final_snapshot_identifier = "inventoria_backup"
  publicly_accessible  = true # need to look into peering with an azure vnet if its not too expensive
  # Tag for resource group
  tags = {
    "rg" = "kleinhapl"
  }
}

# FRONTEND
# task that will pull the container
resource "aws_ecs_task_definition" "frontend-container" {
  family = "inventoria-frontend"
  container_definitions = jsonencode([
    {
      name      = "inventoria-frontend"
      image     = "tiemtom/masterarbeit-frontend"
      cpu       = 512
      memory    = 1024
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 80
        }
      ]
    }
  ])

}

# cluster which will run the container instance
resource "aws_ecs_cluster" "cluster" {
  name = "MA-Kleinhapl"

  tags = {
    "rg" = "kleinhapl"
  }
}

# get most recent amazon linux image
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }
}

# Creating the autoscaling launch configuration that contains AWS EC2 instance details
resource "aws_launch_configuration" "aws_autoscale_conf" {
  name          = "MA-Kleinhapl-launch-config"
  # Defining the image ID of AWS EC2 instance
  image_id      = data.aws_ami.amazon_linux_2.image_id
  # Defining the instance type of the AWS EC2 instance
  instance_type = "t3.medium"
  iam_instance_profile = "ecsInstanceRole"
  key_name = "MA-Kleinhapl"
  # Register instances with cluster
  user_data = "#!/bin/bash\necho ECS_CLUSTER=${aws_ecs_cluster.cluster.name} >> /etc/ecs/ecs.config"
}

resource "aws_autoscaling_group" "auto-scale" {
  name = "auto-scale-MA-Kleinhapl"
  vpc_zone_identifier = ["subnet-fff60c83"]
  desired_capacity = 1
  min_size = 1
  max_size = 1
  launch_configuration = aws_launch_configuration.aws_autoscale_conf.name

    tag {
    key = "ClusterName"
    value = aws_ecs_cluster.cluster.name
    propagate_at_launch = true
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }

  tag {
    key = "rg"
    value = "kleinhapl"
    propagate_at_launch = true
  }
}

resource "aws_ecs_cluster_capacity_providers" "provider-config" {
  cluster_name = aws_ecs_cluster.cluster.name

  capacity_providers = [aws_ecs_capacity_provider.provider.name]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = aws_ecs_capacity_provider.provider.name
  }
}

resource "aws_ecs_capacity_provider" "provider" {
  name = "compute-node"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.auto-scale.arn

    managed_scaling {
      status = "ENABLED"
      maximum_scaling_step_size = 1
      minimum_scaling_step_size = 1
      target_capacity = 1
    }
  }

  tags = {
    "rg" = "kleinhapl"
  }
}

# Start task on ec2 instance
resource "aws_ecs_service" "inventoria_frontend" {
  name            = "inventoria-frontend"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.frontend-container.arn
  desired_count   = 1
}

# BACKEND
  resource "azurerm_service_plan" "app_service_plan_backend" {
  name                = "app-service-plan-frontend"
  resource_group_name = "masterarbeit_kleinhapl"
  location            = "northeurope"
  os_type             = "Linux"
  sku_name            = "B2"
}
resource "azurerm_linux_web_app" "inventoria_backend" {
  name                = "inventoria-backend"
  resource_group_name = "masterarbeit_kleinhapl"
  location            = "northeurope"
  service_plan_id     = azurerm_service_plan.app_service_plan_backend.id
  site_config {
    application_stack {
      docker_image     = "tiemtom/masterarbeit-backend"
      docker_image_tag = "latest"
    }
  }
}
# STORAGE
resource "azurerm_storage_account" "storage" {
  name                     = "inventoriastorage"
  resource_group_name      = "masterarbeit_kleinhapl"
  location                 = "northeurope"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
resource "azurerm_storage_container" "example" {
  name                  = "images"
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "container"
}
