variable "vpc_cidr" {
  type = string
}

variable "vpc_public_subnet_cidrs" {
  type = list(string)
}

variable "region" {
  type = string
}

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "public_key" {
  type = string
}

variable "code_deploy_bucket_name" {
  type = string
}

variable "code_deploy_region" {
  type = string
}

variable "code_deploy_agent_version" {
  type = string
}
