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

import mimetypes
from os import getenv

import functions_framework
from google.api_core.exceptions import GoogleAPIError
from google.cloud.video import transcoder_v1
from google.cloud.video.transcoder_v1.services.transcoder_service import \
    TranscoderServiceClient


# Register a CloudEvent function with the Function Framework
@functions_framework.cloud_event
def vod_ingestion(cloud_event):
    """Triggered by a change to a Cloud Storage bucket.
    Args:
         cloud_event: Eventarc cloud event
    """
    project_id = getenv('TRANSCODE_PROJECT_ID')
    location = getenv('TRANSCODE_REGION')
    output_bucket = getenv('TRANSCODE_SERVING_BUCKET')
    parent = f"projects/{project_id}/locations/{location}"

    bucket = cloud_event.data['bucket']
    path = cloud_event.data['name']
    mime_type = cloud_event.data['contentType']

    # Only process video files
    if not mime_type.startswith('video/'):
        guessed_mime_type = mimetypes.guess_type(path)[0]
        if guessed_mime_type.startswith('video/'):
            mime_type = guessed_mime_type
        else:
            print(f"Ignoring gs://{bucket}/{path} non video "
                  f"mime_type: {mime_type}; guessed {guessed_mime_type}")
            return

    # Remove mime type video suffix to form output directory
    # e.g. gs://vod_upload/foo/bar/baz/example.mp4 (video/mp4) ->
    #      gs://vod_serving/foo/bar/baz/example/
    output_path = path
    for suffix in mimetypes.guess_all_extensions(mime_type):
        if output_path.endswith(suffix):
            output_path = output_path.removesuffix(suffix)
            break

    client = TranscoderServiceClient()

    job = transcoder_v1.types.Job()
    job.input_uri = f"gs://{bucket}/{path}"
    job.output_uri = f"gs://{output_bucket}/{output_path}/"
    # Transcode job preset
    job.template_id = "preset/web-hd"

    try:
        client.create_job(parent=parent, job=job)
        print(f"Transcoding {job.input_uri} -> {job.output_uri}")
    except GoogleAPIError as e:
        # Capturing the exception - prevents Eventarc retrying
        print("ERROR: Transcode job creation failed.", e)
    return
