#!/bin/bash

# Config options

BUILDKITE_PLUGIN_DOCKER_COMPOSE_IMAGE_REPOSITORY="${BUILDKITE_PLUGIN_DOCKER_COMPOSE_IMAGE_REPOSITORY:-}"

# Local vars

COMPOSE_SERVICE_OVERRIDE_FILE="docker-compose.buildkite-$BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD-override.yml"
IMAGE_NAME="${BUILDKITE_PROJECT_SLUG}-${BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD}-build-${BUILDKITE_BUILD_NUMBER}}"

if [[ -z "$BUILDKITE_PLUGIN_DOCKER_COMPOSE_IMAGE_REPOSITORY" ]] ; then
  BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_TAG="$BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD:$IMAGE_NAME"
else
  BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_TAG="$BUILDKITE_PLUGIN_DOCKER_COMPOSE_IMAGE_REPOSITORY:$IMAGE_NAME"
fi

push_image_to_docker_repository() {
  local tag="$BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_TAG"

  plugin_prompt_and_must_run docker push "$tag"
  plugin_prompt_and_must_run buildkite-agent meta-data set "$(build_meta_data_image_tag_key "$BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD")" "$tag"
}

echo "~~~ :docker: Creating a modified Docker Compose config"

# Override the config so that the service uses the restored image instead of building
cat > $COMPOSE_SERVICE_OVERRIDE_FILE <<EOF
version: '2'
services:
  $BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD:
    image: $BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_TAG
EOF
cat $COMPOSE_SERVICE_OVERRIDE_FILE

echo "+++ :docker: Building Docker Compose images for service $BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD"

run_docker_compose -f "$COMPOSE_SERVICE_OVERRIDE_FILE" build "$BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD"

if [[ ! -z "$BUILDKITE_PLUGIN_DOCKER_COMPOSE_IMAGE_REPOSITORY" ]]; then
  echo "~~~ :docker: Pushing image to $BUILDKITE_PLUGIN_DOCKER_COMPOSE_IMAGE_REPOSITORY"

  push_image_to_docker_repository
fi
