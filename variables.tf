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
# ADC/ALM migration variables (added in v2.0.0 to make the module env-agnostic).
# See b/540892131 (parent b/540890659).
#
# These MUST be passed by the caller (via ADC Component metadata.yaml or
# Unit Kind Release variables). No defaults so a mis-configured env fails
# loudly at plan time rather than silently pointing at autopush.
variable "producer_project_id" {
  description = <<-EOT
    Producer project ID that owns the runtime SA and the ALM management
    resources. One per env:
      - autopush: ez-agentengine-autopush
      - staging:  ez-agentengine-staging
      - prod:     ez-agentengine-prod
  EOT
  type        = string
}
variable "runtime_service_account_email" {
  description = <<-EOT
    Email of the SA used as Cloud Run runtime identity for AE tenants. Lives
    in `producer_project_id`; different per env:
      - autopush: generic-vertex-sa-poc@ez-agentengine-autopush.iam.gserviceaccount.com
      - staging:  generic-vertex-sa@ez-agentengine-staging.iam.gserviceaccount.com
      - prod:     generic-vertex-sa@ez-agentengine-prod.iam.gserviceaccount.com
    (Note POC's `-poc` suffix is intentionally dropped in staging/prod.)
  EOT
  type        = string
}
