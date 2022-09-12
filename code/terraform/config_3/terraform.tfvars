# ------------------------Variable Declaration------------------------
# AWS and Azure regions
aws_region = "eu-central-1"
azure_region = "northeurope"

# Azure resource group, should already exist, it will not be created by Terraform
azure_rg = "AZURE_RG"

# DB user and password, if chnged, adjust local provisioners on DB
db_user = "tom"
db_passwd = "Pa55w.rd"

# Custom vision
custom_vision_url = "CUSTOM_VISION_URL" # leave string empty if running without custom vision ("")
custom_vision_key = "CUSTOM_VISION_KEY"

# AWS IAM credentials, needed for S3 storage access, can be left empty of storage is on Azure
aws_iam_id = "IAM_ID"
aws_iam_key = "IAM_KEY"