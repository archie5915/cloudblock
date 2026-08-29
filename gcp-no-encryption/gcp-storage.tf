resource "google_storage_bucket" "ph-bucket" {
  name                        = "${var.ph_prefix}-bucket-${random_string.ph-random.result}"
  location                    = var.gcp_region
  project                     = google_project.ph-project.project_id
  uniform_bucket_level_access = true
  versioning {
    enabled = false
  }
  force_destroy = true
}

resource "google_storage_bucket_iam_member" "ph-bucket-user-admin" {
  bucket = google_storage_bucket.ph-bucket.name
  role   = "roles/storage.admin"
  member = "user:${var.gcp_user}"
}

resource "google_storage_bucket_iam_member" "ph-bucket-service-account-object-admin" {
  bucket = google_storage_bucket.ph-bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.ph-service-account.email}"
}
