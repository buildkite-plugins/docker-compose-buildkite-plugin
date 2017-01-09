#!/bin/bash

COMPOSE_SERVICE_NAME="$BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD"
COMPOSE_SERVICE_DOCKER_IMAGE_NAME="$(docker_compose_container_name "$COMPOSE_SERVICE_NAME")"
DOCKER_IMAGE_REPOSITORY="${BUILDKITE_PLUGIN_DOCKER_COMPOSE_IMAGE_REPOSITORY:-}"
COMPOSE_SERVICE_OVERRIDE_FILE="docker-compose.buildkite-$COMPOSE_SERVICE_NAME-override.yml"

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
  local tag="$BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_TAG"

  plugin_prompt_and_must_run docker push "$tag"
  plugin_prompt_and_must_run buildkite-agent meta-data set "$(build_meta_data_image_tag_key "$COMPOSE_SERVICE_NAME")" "$tag"
}

if [[ -z "$DOCKER_IMAGE_REPOSITORY" ]] ; then
  BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_TAG="$COMPOSE_SERVICE_NAME:$(image_file_name)"
else
  BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_TAG="$DOCKER_IMAGE_REPOSITORY:$(image_file_name)"
fi

echo "~~~ :docker: Creating a modified Docker Compose config"

# Override the config so that the service uses the restored image instead of building
cat > $COMPOSE_SERVICE_OVERRIDE_FILE <<EOF
version: '2'
services:
  $COMPOSE_SERVICE_NAME:
    image: $BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_TAG
EOF
cat $COMPOSE_SERVICE_OVERRIDE_FILE

echo "+++ :docker: Building Docker Compose images for service $COMPOSE_SERVICE_NAME"

run_docker_compose -f "$COMPOSE_SERVICE_OVERRIDE_FILE" build "$COMPOSE_SERVICE_NAME"

if [[ ! -z "$DOCKER_IMAGE_REPOSITORY" ]]; then
  echo "~~~ :docker: Pushing image $COMPOSE_SERVICE_DOCKER_IMAGE_NAME to $DOCKER_IMAGE_REPOSITORY"

  push_image_to_docker_repository
fi
