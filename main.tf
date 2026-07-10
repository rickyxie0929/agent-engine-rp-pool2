# ---------------------------------------------------------------------------------
# 1. API & Service Agent Initialization
# ---------------------------------------------------------------------------------
resource "google_project_service" "cloudrun" {
  project            = var.tenant_project_id
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service_identity" "cloudrun_sa" {
  provider = google-beta
  project  = var.tenant_project_id
  service  = "run.googleapis.com"

  depends_on = [google_project_service.cloudrun]
}

# ---------------------------------------------------------------------------------
# 2. IAM Delegation (Mimics VRP `GrantServiceAccountPayload`)
# Grants the Cloud Run Service Agent permission to generate tokens for the Vertex P4SA
# ---------------------------------------------------------------------------------
resource "google_service_account_iam_member" "cloudrun_p4sa_token_creator" {
  # The Resource: A generic SA in the producer project (kshalu-org-1)
  # Ensure this SA is created in the producer project before running!
  service_account_id = "projects/kshalu-org-1/serviceAccounts/generic-vertex-sa@kshalu-org-1.iam.gserviceaccount.com"
  
  role               = "roles/iam.serviceAccountTokenCreator"
  
  # The Member: The Cloud Run Service Agent for the Tenant Project
  member             = "serviceAccount:${google_project_service_identity.cloudrun_sa.email}"
}

# ---------------------------------------------------------------------------------
# 3. Creating the Memory bank service account for this tenant project
# ---------------------------------------------------------------------------------
resource "google_service_account" "memory_bank_sa" {
  account_id   = "memory-bank"
  project      = var.tenant_project_id
  display_name = "Memory Bank Service Account"
}

# ---------------------------------------------------------------------------------
# 4. granting the AE control plane the borg role roken creator role on the memory bank SA. 
# Note: in real world we will be sending the control plane borg service account based on the environment(autopush, staging, prod). 
# For now we will be using the projects/kshalu-org-1/serviceAccounts/generic-vertex-sa@kshalu-org-1.iam.gserviceaccount.com for this purpose
# ---------------------------------------------------------------------------------
resource "google_service_account_iam_member" "ae_control_plane_token_creator" {
  service_account_id = google_service_account.memory_bank_sa.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:generic-vertex-sa@kshalu-org-1.iam.gserviceaccount.com"

  depends_on = [google_service_account.memory_bank_sa]
}

# ---------------------------------------------------------------------------------
# 5. Dry-Run Initialization (Warms Regional Cache & Validates IAM Setup)
# Replaces the physical Cloud Run Service to achieve $0.00 billing and 0 active state
# ---------------------------------------------------------------------------------

# Dynamic client config helper to safely extract the ADC authorization token of your deployment pipeline
data "google_client_config" "current" {}

data "http" "prewarmed_init_dry_run" {
  # Direct regional API endpoint with serviceId and validateOnly queries to trigger regional cell registration
  url    = "https://${var.location}-run.googleapis.com/v2/projects/${var.tenant_project_id}/locations/${var.location}/services?serviceId=agent-engine-cloud-run-dry-run-service&validateOnly=true"
  method = "POST"

  request_headers = {
    Authorization = "Bearer ${data.google_client_config.current.access_token}"
    Content-Type  = "application/json"
  }

  # Translating your original Cloud Run v2 configuration directly into the Cloud Run v2 JSON Service Schema
  request_body = jsonencode({
    ingress = "INGRESS_TRAFFIC_INTERNAL_ONLY"
    
    labels = {
      "managed-by" = "reasoning-engine"
    }

    template = {
      serviceAccount = "generic-vertex-sa@kshalu-org-1.iam.gserviceaccount.com"
      
      containers = [
        {
          image = "us-docker.pkg.dev/cloudrun/container/hello:latest"
        }
      ]
    }
  })

  depends_on = [
    # Explicit dependency ensures the service identity & token creator role exists before dry-run validation is triggered
    google_project_service_identity.cloudrun_sa,
    google_service_account_iam_member.cloudrun_p4sa_token_creator,
    google_service_account_iam_member.ae_control_plane_token_creator
  ]
}
