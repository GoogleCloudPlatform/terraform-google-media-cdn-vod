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

output "upload_bucket" {
  description = "The VOD upload bucket"
  value       = google_storage_bucket.vod_upload.url
}

output "serving_bucket" {
  description = "The VOD serving bucket and Media CDN origin"
  value       = google_storage_bucket.vod_serving.url
}

output "media_cdn_ipv4" {
  description = "The Media CDN serving address"
  value       = google_network_services_edge_cache_service.default.ipv4_addresses[0]
}

output "media_cdn_index" {
  description = "VOD landing page URL"
  value       = "http://${google_network_services_edge_cache_service.default.ipv4_addresses[0]}/index.html"
}
