#!/bin/bash

COMPOSE_SERVICE_NAME="$BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD"
SERVICE_DOCKER_IMAGE_NAME="$(docker_compose_container_name "$COMPOSE_SERVICE_NAME")"

save_image_as_artifact() {
  local build_meta_data_key="$(build_meta_data_artifact_key "$COMPOSE_SERVICE_NAME")"

  # Turn org/project -> project
  local project_name=$(echo "$BUILDKITE_PROJECT_SLUG" | sed 's/^\([^\/]*\/\)//g')

  # Name the tgz the same as the service docker image name
  local image_tgz_path="$project_name-$COMPOSE_SERVICE_NAME-build-$BUILDKITE_BUILD_NUMBER.tgz"

  # Save down the image
  buildkite-run "docker save $SERVICE_DOCKER_IMAGE_NAME | gzip -c > $image_tgz_path"

  # Upload the image
  buildkite-run "buildkite-agent artifact upload \"$image_tgz_path\""

  # Store as build meta-data
  buildkite-run "buildkite-agent meta-data set \"$build_meta_data_key\" \"$image_tgz_path\""
}

echo "+++ Building Docker Compose images for service $SERVICE_DOCKER_IMAGE_NAME"

run_docker_compose "build" "$SERVICE_DOCKER_IMAGE_NAME"

echo "~~~ Listing docker images"

buildkite-run "docker ps | grep buildkite"
buildkite-run "docker images | grep buildkite"

echo "~~~ Storing the image"

# In the future we can branch based on artifact or private registry storage

save_image_as_artifact
