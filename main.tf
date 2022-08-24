# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Random suffix tied to project -- used on resources with global naming

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

data "google_project" "project" {
  project_id = var.project_id
}

resource "random_id" "suffix" {
  keepers = {
    # Generate a new id when project changes
    project = var.project_id
  }
  byte_length = 2
}

data "google_storage_project_service_account" "gcs_account" {
  project = var.project_id
}

locals {
  # mediaedge doesn't yet support google_project_service_identity
  mediaedgefill_email = "service-${data.google_project.project.number}@gcp-sa-mediaedgefill.iam.gserviceaccount.com"
}

module "project_services" {
  source                      = "terraform-google-modules/project-factory/google//modules/project_services"
  version                     = "13.0.0"
  disable_services_on_destroy = false
  project_id                  = var.project_id
  enable_apis                 = var.enable_apis

  activate_apis = [
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudfunctions.googleapis.com",
    "compute.googleapis.com",
    "edgecache.googleapis.com",
    "eventarc.googleapis.com",
    "iam.googleapis.com",
    "networkservices.googleapis.com",
    "pubsub.googleapis.com",
    "run.googleapis.com",
    "storage-api.googleapis.com",
    "storage.googleapis.com",
    "transcoder.googleapis.com",
  ]
}

resource "google_project_service_identity" "service_identities" {
  provider = google-beta

  for_each = toset([
    "transcoder.googleapis.com",
  ])
  service = each.value

  depends_on = [module.project_services]
}

resource "google_storage_bucket" "gcf_source" {
  name                        = "gcf-source-${random_id.suffix.hex}"
  location                    = var.region
  force_destroy               = false
  uniform_bucket_level_access = true
  labels                      = var.labels

  depends_on = [module.project_services]
}

resource "google_storage_bucket" "vod_upload" {
  name                        = "vod-upload-${random_id.suffix.hex}"
  location                    = var.region
  force_destroy               = false
  uniform_bucket_level_access = true
  labels                      = var.labels

  depends_on = [module.project_services]
}
resource "google_storage_bucket" "vod_serving" {
  name                        = "vod-serving-${random_id.suffix.hex}"
  location                    = var.region
  force_destroy               = true
  uniform_bucket_level_access = true
  labels                      = var.labels

  cors {
    origin          = ["https://shaka-player-demo.appspot.com/"]
    response_header = ["Content-Type", "Range"]
    method          = ["GET", "HEAD"]
    max_age_seconds = 3600
  }

  depends_on = [module.project_services]
}

resource "google_network_services_edge_cache_origin" "default" {
  name           = "vod-origin"
  origin_address = google_storage_bucket.vod_serving.url
  max_attempts   = 2
  labels         = var.labels

  timeout {
    connect_timeout = "10s"
  }

  depends_on = [module.project_services]
}

resource "google_network_services_edge_cache_service" "default" {
  name   = "vod-service"
  labels = var.labels

  routing {
    host_rule {
      hosts        = ["*"]
      path_matcher = "routes"
    }
    path_matcher {
      name = "routes"
      route_rule {
        priority = 1
        match_rule {
          prefix_match = "/"
        }
        origin = google_network_services_edge_cache_origin.default.name
        route_action {
          cdn_policy {
            cache_mode  = "FORCE_CACHE_ALL"
            default_ttl = "3600s"
          }
        }
        header_action {
          response_header_to_add {
            header_name  = "x-cache-status"
            header_value = "{cdn_cache_status}"
          }
        }
      }
    }
  }

  depends_on = [module.project_services]
}

resource "google_storage_bucket_iam_member" "media_edge" {
  bucket = google_storage_bucket.vod_serving.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${local.mediaedgefill_email}"

  depends_on = [module.project_services]
}

# Allow the google storage service account to publish to Eventarc pubsub
resource "google_project_iam_member" "gcs-pubsub-publishing" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"

  depends_on = [module.project_services]
}

resource "google_service_account" "transcode_sa" {
  account_id   = "transcode-sa"
  display_name = <<-EOT
  Service account used by both the Transcode Cloud Function and Eventarc trigger
  EOT

  depends_on = [module.project_services]
}

resource "google_project_iam_member" "invoking" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.transcode_sa.email}"
}

resource "google_project_iam_member" "event-receiving" {
  project = var.project_id
  role    = "roles/eventarc.eventReceiver"
  member  = "serviceAccount:${google_service_account.transcode_sa.email}"
}

resource "google_project_iam_member" "artifactregistry-reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.transcode_sa.email}"
}

resource "google_project_iam_member" "transcoder" {
  project = var.project_id
  role    = "roles/transcoder.admin"
  member  = "serviceAccount:${google_service_account.transcode_sa.email}"
}

data "archive_file" "ingestion" {
  type        = "zip"
  source_dir  = "${path.root}/source/ingestion"
  output_path = "${path.root}/build/ingestion.zip"
}

# upload he ingestion function source zipfile to cloud storage
resource "google_storage_bucket_object" "ingestion_source" {
  name   = "ingestion.zip"
  source = data.archive_file.ingestion.output_path
  bucket = google_storage_bucket.gcf_source.name
}

resource "google_storage_bucket_object" "test_video" {
  name   = "smpte.mp4"
  source = "smpte.mp4"
  bucket = google_storage_bucket.vod_upload.name

  depends_on = [google_cloudfunctions2_function.vod_ingestion]
}

resource "google_cloudfunctions2_function" "vod_ingestion" {
  provider    = google-beta
  location    = var.region
  name        = "vod-ingestion"
  description = <<-EOT
  Cloud function that invokes a Transcode API job on objects added to
  vod_upload bucket
  EOT
  labels      = var.labels


  build_config {
    runtime     = "python310"
    entry_point = "vod_ingestion"
    source {
      storage_source {
        bucket = google_storage_bucket.gcf_source.name
        object = google_storage_bucket_object.ingestion_source.output_name
      }
    }
  }

  service_config {
    max_instance_count = 3
    min_instance_count = 0
    available_memory   = "256M"
    timeout_seconds    = 60
    environment_variables = {
      TRANSCODE_PROJECT_ID     = var.project_id
      TRANSCODE_REGION         = var.region
      TRANSCODE_SERVING_BUCKET = google_storage_bucket.vod_serving.name
    }
    ingress_settings               = "ALLOW_INTERNAL_ONLY"
    all_traffic_on_latest_revision = true
    service_account_email          = google_service_account.transcode_sa.email

  }

  event_trigger {
    trigger_region        = var.region
    event_type            = "google.cloud.storage.object.v1.finalized"
    retry_policy          = "RETRY_POLICY_RETRY"
    service_account_email = google_service_account.transcode_sa.email
    event_filters {
      attribute = "bucket"
      value     = google_storage_bucket.vod_upload.name
    }
  }

  depends_on = [
    module.project_services,
    google_project_iam_member.event-receiving,
    google_project_iam_member.artifactregistry-reader,
  ]
}

resource "google_storage_bucket_iam_member" "transcoder-read" {
  bucket = google_storage_bucket.vod_upload.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_project_service_identity.service_identities["transcoder.googleapis.com"].email}"
}

resource "google_storage_bucket_iam_member" "transcoder-write" {
  bucket = google_storage_bucket.vod_serving.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_project_service_identity.service_identities["transcoder.googleapis.com"].email}"
}
