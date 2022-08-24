# Terraform Google Media CDN VOD


This module demonstrates deploying a Media CDN Video on Demand solution. It
creates two Cloud Storage buckets:

 - `vod-upload-<random_suffix>`: Upload raw video files here
 - `vod-serving-<random_suffix>`: Transcoded video serving bucket.

A Google Cloud Function triggers a Transcoder API job convert and package raw
video files uploaded to the `vod-upload`. Transcoded output is written to the
`vod-serving` bucket.

A Media CDN service and origin is configured to serve the transcoded output.

The resources/services/activations/deletions that this module will
create/trigger are:

- Two Cloud Storage buckets
- A Google Cloud Function
- A Media CDN service and origin

## Usage

Basic usage of this module is as follows:

```hcl
module "media_cdn_vod" {
  source  = "terraform-google-modules/media_cdn_vod/google"
  version = "~> 0.1"
  project_id  = "<PROJECT ID>"
  region = "us-central1"
```

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| enable\_apis | Whether or not to enable underlying apis in this solution. | `string` | `"true"` | no |
| labels | A map of labels to apply to resources deployed by this blueprint | `map(string)` | <pre>{<br>  "media-cdn-vod": true<br>}</pre> | no |
| project\_id | The Project ID to deploy to | `string` | n/a | yes |
| region | The Compute Region to deploy to | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| media\_cdn\_ipv4 | The Media CDN serving address |
| serving\_bucket | The VOD serving bucket and Media CDN origin |
| upload\_bucket | The VOD upload bucket |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## Requirements

These sections describe requirements for using this module.

### Software

The following dependencies must be available:

- [Terraform](https://www.terraform.io/downloads.html) >= 1.1.9
- [Terraform Provider for GCP][terraform-provider-gcp] plugin >= v4.33

### Service Account

User or service account credentials with the following roles must be used to
provision the resources of this module:

- Storage Admin: `roles/storage.admin`

The [Project Factory module][project-factory-module] and the
[IAM module][iam-module] may be used in combination to provision a
service account with the necessary roles applied.

### APIs

A project with the following APIs enabled must be used to host the
resources of this module:

  - Artifact Registry - `artifactregistry.googleapis.com`
  - Cloud Build API - `cloudbuild.googleapis.com`
  - Cloud Functions API - `cloudfunctions.googleapis.com`
  - Compute Engine API - `compute.googleapis.com`
  - Global Edge Cache Service (Media CDN) - `edgecache.googleapis.com`
  - Eventarc API - `eventarc.googleapis.com`
  - Identity and Access Management (IAM) API - `iam.googleapis.com`
  - Network Services API - `networkservices.googleapis.com`
  - Cloud Pub/Sub API - `pubsub.googleapis.com`
  - Cloud Run API - `run.googleapis.com`
  - Cloud Storage JSON API - `storage-api.googleapis.com`
  - Transcoder API - `transcoder.googleapis.com`

The [Project Factory module][project-factory-module] can be used to
provision a project with the necessary APIs enabled.

## Contributing

Refer to the [contribution guidelines](./CONTRIBUTING.md) for
information on contributing to this module.

[iam-module]: https://registry.terraform.io/modules/terraform-google-modules/iam/google
[project-factory-module]: https://registry.terraform.io/modules/terraform-google-modules/project-factory/google
[terraform-provider-gcp]: https://www.terraform.io/docs/providers/google/index.html
[terraform]: https://www.terraform.io/downloads.html

## Security Disclosures

Please see our [security disclosure process](./SECURITY.md).
