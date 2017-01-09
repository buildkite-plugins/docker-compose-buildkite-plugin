#!/bin/bash

COMPOSE_SERVICE_NAME="$BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD"
COMPOSE_SERVICE_DOCKER_IMAGE_NAME="$(docker_compose_container_name "$COMPOSE_SERVICE_NAME")"
DOCKER_IMAGE_REPOSITORY="${BUILDKITE_PLUGIN_DOCKER_COMPOSE_IMAGE_REPOSITORY:-}"
COMPOSE_SERVICE_OVERRIDE_FILE="docker-compose.buildkite-$COMPOSE_SERVICE_NAME-override.yml"
IMAGE_NAME="${BUILDKITE_PROJECT_SLUG}-${COMPOSE_SERVICE_NAME}-build-${BUILDKITE_BUILD_NUMBER}"

push_image_to_docker_repository() {
  local tag="$BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_TAG"

  plugin_prompt_and_must_run docker push "$tag"
  plugin_prompt_and_must_run buildkite-agent meta-data set "$(build_meta_data_image_tag_key "$COMPOSE_SERVICE_NAME")" "$tag"
}

if [[ -z "$DOCKER_IMAGE_REPOSITORY" ]] ; then
  BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_TAG="$COMPOSE_SERVICE_NAME:$IMAGE_NAME"
else
  BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_TAG="$DOCKER_IMAGE_REPOSITORY:$IMAGE_NAME"
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
