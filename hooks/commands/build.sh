#!/bin/bash

COMPOSE_SERVICE_NAME="$BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD"
COMPOSE_SERVICE_DOCKER_IMAGE_NAME="$(docker_compose_container_name "$COMPOSE_SERVICE_NAME")"
DOCKER_IMAGE_REPOSITORY="${BUILDKITE_PLUGIN_DOCKER_COMPOSE_IMAGE_REPOSITORY:-}"

# Returns a friendly image file name like "myproject-app-build-49" than can be
# used as the docker image tag or tar.gz filename
image_file_name() {
  # The project slug env variable includes the org (e.g. "org/project"), so we
  # have to strip the org from the front (e.g. "project")
  local project_name=$(echo "$BUILDKITE_PROJECT_SLUG" | sed 's/^\([^\/]*\/\)//g')
  # look for custom image tag string (i.e. "latest")
  if [[ ! -z "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_IMAGE_TAG:-}" ]]; then
    echo "$BUILDKITE_PLUGIN_DOCKER_COMPOSE_IMAGE_TAG"
  else
    echo "$project_name-$COMPOSE_SERVICE_NAME-build-$BUILDKITE_BUILD_NUMBER"
  fi
}

push_image_to_docker_repository() {
  local tag="$DOCKER_IMAGE_REPOSITORY:$(image_file_name)"

  plugin_prompt_and_must_run docker tag "$COMPOSE_SERVICE_DOCKER_IMAGE_NAME" "$tag"
  plugin_prompt_and_must_run docker push "$tag"
  plugin_prompt_and_must_run docker rmi "$tag"

  plugin_prompt_and_must_run buildkite-agent meta-data set "$(build_meta_data_image_tag_key "$COMPOSE_SERVICE_NAME")" "$tag"
}

echo "+++ :docker: Building Docker Compose images for service $COMPOSE_SERVICE_NAME"

run_docker_compose build "$COMPOSE_SERVICE_NAME"

echo "~~~ :docker: Listing docker images"

plugin_prompt docker images
docker images | grep buildkite

if [[ ! -z "$DOCKER_IMAGE_REPOSITORY" ]]; then
  echo "~~~ :docker: Pushing image $COMPOSE_SERVICE_DOCKER_IMAGE_NAME to $DOCKER_IMAGE_REPOSITORY"

  push_image_to_docker_repository
fi
