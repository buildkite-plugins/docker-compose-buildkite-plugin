#!/bin/bash

compose_service_name() {
  echo "$BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD"
}

service_docker_image_name() {
  docker_compose_container_name "$(compose_service_name)"
}

build_meta_data_artifact_key() {
  echo "docker-compose-plugin-built-image-artifact-$(service_docker_image_name)"
}

save_image_as_artifact() {
  # Name the tgz the same as the service docker image name
  local image_tgz_path="$(compose_service_name)-build-$BUILDKITE_BUILD_NUMBER.tgz"

  # Save down the image
  buildkite-run "docker save $(service_docker_image_name) | gzip -c > $image_tgz_path"

  # Upload the image
  buildkite-run "buildkite-agent artifact upload \"$image_tgz_path\""

  # Store as build meta-data
  buildkite-run "buildkite-agent meta-data set \"$(build_meta_data_artifact_key)\" \"$image_tgz_path\""
}

echo "+++ Building Docker Compose images for service $(service_docker_image_name)"

run_docker_compose "build" "$(service_docker_image_name)"

echo "~~~ Listing docker images"

buildkite-run "docker ps | grep buildkite"
buildkite-run "docker images | grep buildkite"

echo "~~~ Storing the image"

# In the future we can branch based on artifact or private registry storage

save_image_as_artifact
