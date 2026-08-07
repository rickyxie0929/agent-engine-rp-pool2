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

resource "google_service_account" "ae_runtime_sa" {
  account_id   = "ae-runtime"
  project      = var.tenant_project_id
  display_name = "AE Cloud Run Runtime SA"
}

resource "google_service_account_iam_member" "cloudrun_sa_runtime_token_creator" {
  service_account_id = google_service_account.ae_runtime_sa.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_project_service_identity.cloudrun_sa.email}"
  depends_on         = [google_service_account.ae_runtime_sa]
}

resource "google_service_account" "memory_bank_sa" {
  account_id   = "memory-bank"
  project      = var.tenant_project_id
  display_name = "Memory Bank Service Account"
}

resource "google_project_iam_member" "memory_bank_endpoints_editor" {
  project    = var.tenant_project_id
  role       = "organizations/433637338589/roles/aiplatform_endpoints_editor"
  member     = "serviceAccount:${google_service_account.memory_bank_sa.email}"
  depends_on = [google_service_account.memory_bank_sa]
}

resource "google_service_account_iam_member" "ae_cp_nonprod_token_creator" {
  service_account_id = google_service_account.memory_bank_sa.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "user:vertex-ai-agent-engine-controlplane-nonprod-jobs@prod.google.com"
  depends_on         = [google_service_account.memory_bank_sa]
}

resource "google_service_account_iam_member" "ae_cp_prod_token_creator" {
  service_account_id = google_service_account.memory_bank_sa.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "user:vertex-ai-agent-engine-controlplane@prod.google.com"
  depends_on         = [google_service_account.memory_bank_sa]
}

data "google_client_config" "current" {}

data "http" "prewarmed_init_dry_run" {
  url    = "https://${var.location}-run.googleapis.com/v2/projects/${var.tenant_project_id}/locations/${var.location}/services?serviceId=agent-engine-cloud-run-dry-run-service&validateOnly=true"
  method = "POST"
  request_headers = {
    Authorization = "Bearer ${data.google_client_config.current.access_token}"
    Content-Type  = "application/json"
  }
  request_body = jsonencode({
    ingress = "INGRESS_TRAFFIC_INTERNAL_ONLY"
    labels  = { "managed-by" = "reasoning-engine" }
    template = {
      serviceAccount = google_service_account.ae_runtime_sa.email
      containers     = [{ image = "us-docker.pkg.dev/cloudrun/container/hello:latest" }]
    }
  })
  depends_on = [
    google_project_service_identity.cloudrun_sa,
    google_service_account_iam_member.cloudrun_sa_runtime_token_creator,
    google_service_account_iam_member.ae_cp_nonprod_token_creator,
    google_service_account_iam_member.ae_cp_prod_token_creator,
    google_project_iam_member.memory_bank_endpoints_editor,
  ]
}
