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

resource "google_compute_security_policy" "edgepolicy" {
  project     = module.project_services.project_id
  name        = "vod-edgepolicy-${random_id.suffix.hex}"
  description = "edge rules"
  type        = "CLOUD_ARMOR_EDGE"

  rule {
    action   = "deny(403)"
    priority = "7000"
    preview  = false
    match {
      expr {
        expression = "origin.region_code == 'GB'"
      }
    }
    description = "Deny access from GB (Great Britain)"
  }
  rule {
    action   = "deny(403)"
    priority = "7001"
    preview  = false
    match {
      expr {
        expression = "origin.region_code == 'FR'"
      }
    }
    description = "Deny access from FR (France)"
  }
  rule {
    action   = "allow"
    priority = "2147483647"
    preview  = false
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "default rule"
  }
}
