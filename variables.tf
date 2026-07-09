variable "tenant_project_id" {
  description = "The Tenant Project ID"
  type        = string
}

variable "tenant_project_number" {
  description = "The Tenant Project Number"
  type        = string
}

variable "location" {
  description = "The region (e.g. us-central1)"
  type        = string
  default     = "us-central1"
}
