# The pre-warmed Cloud Run service is now configured as a dry-run and not provisioned, 
# therefore service name and URI outputs have been removed.

output "tenant_project_id" {
  description = "The project ID where the resources were deployed"
  value       = var.tenant_project_id
}
