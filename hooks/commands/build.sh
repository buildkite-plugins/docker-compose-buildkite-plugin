#!/bin/bash

COMPOSE_SERVICE_NAME="$BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD"
COMPOSE_SERVICE_DOCKER_IMAGE_NAME="$(docker_compose_container_name "$COMPOSE_SERVICE_NAME")"

# Returns a friendly image file name like "myproject-app-build-49" than can be
# used as the docker image tag or tar.gz filename
image_file_name() {
  # The project slug env variable includes the org (e.g. "org/project"), so we
  # have to strip the org from the front (e.g. "project")
  local project_name=$(echo "$BUILDKITE_PROJECT_SLUG" | sed 's/^\([^\/]*\/\)//g')

  echo "$project_name-$COMPOSE_SERVICE_NAME-build-$BUILDKITE_BUILD_NUMBER"
}

save_image_as_artifact() {
  local image_tgz_path="$(image_file_name).tgz"

  # Save down the image
  buildkite-run "docker save $COMPOSE_SERVICE_DOCKER_IMAGE_NAME | gzip -c > $image_tgz_path"

  # Upload the image
  buildkite-run "buildkite-agent artifact upload \"$image_tgz_path\""

  # Store as build meta-data
  buildkite-run "buildkite-agent meta-data set \"$(build_meta_data_artifact_key "$COMPOSE_SERVICE_NAME")\" \"$image_tgz_path\""
}

save_image_to_docker_repository() {
  local tag="$BUILDKITE_PLUGIN_DOCKER_COMPOSE_IMAGE_REPOSITORY:$(image_file_name)"

  buildkite-run "docker tag $COMPOSE_SERVICE_DOCKER_IMAGE_NAME $tag"
  buildkite-run "docker push $tag"
  buildkite-run "docker rmi $tag"

  buildkite-run "buildkite-agent meta-data set \"$(build_meta_data_image_tag_key "$COMPOSE_SERVICE_NAME")\" \"$tag\""
}

echo "+++ Building Docker Compose images for service $COMPOSE_SERVICE_NAME"

run_docker_compose "build" "$COMPOSE_SERVICE_NAME"

echo "~~~ Listing docker images"

buildkite-run "docker ps"
buildkite-run "docker ps | grep buildkite"
buildkite-run "docker images | grep buildkite"

echo "~~~ Storing the image"

# In the future we can branch based on artifact or private registry storage

if [[ "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_IMAGE_REPOSITORY:-artifact}" -e "artifact" ]]; then
  save_image_as_artifact
else
  save_image_to_docker_repository
fi
