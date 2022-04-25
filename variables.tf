variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rsg-dwh-uat-01"
}

variable "preferred_location" {
  description = "Preferred region for deploying services"
  type        = string
  default     = "West US"
}
