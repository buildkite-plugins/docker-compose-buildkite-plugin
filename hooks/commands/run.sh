#!/bin/bash

COMPOSE_SERVICE_NAME="$BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN"

check_required_args() {
  if [[ -z "${BUILDKITE_COMMAND:-}" ]]; then
    echo "No command to run. Did you provide a 'command' for this step?"
    exit 1
  fi
}

check_required_args

compose_force_cleanup() {
  echo "~~~ Cleaning up Docker containers"

  run_docker_compose "kill" || true
  run_docker_compose "rm --force -v" || true

  # This isn't cleaned up by compose, so we have to do it ourselves
  local adhoc_run_container_name="${BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN}_run_1"
  buildkite-run "docker rm -f -v $(docker_compose_container_name \"$adhoc_run_container_name\")" || true
}

trap compose_force_cleanup EXIT

try_image_restore_from_artifact() {
  local artifact_name=$(buildkite-agent meta-data get "$(build_meta_data_artifact_key "$COMPOSE_SERVICE_NAME")")

  if [[ ! -z "$artifact_name" ]]; then
    echo "Docker image found in artifact \"$artifact_name\""
    buildkite-run "buildkite-agent artifact download \"$artifact_name\""

    echo "Loading into docker..."
    buildkite-run "gunzip -c \"$artifact_name\" | docker load"
  fi
}

try_image_restore_from_docker_repository() {
  local tag=$(buildkite-agent meta-data get "$(build_meta_data_image_tag_key "$COMPOSE_SERVICE_NAME")")

  if [[ ! -z "$tag" ]]; then
    echo "Docker image found in repository with key \"$build_meta_data_image_tag_key\""

    echo "TODO: Rewrite Docker Compose config"

    exit 1
  fi
}

echo "~~~ Checking for pre-built images"

try_image_restore_from_artifact
try_image_restore_from_docker_repository

echo "~~~ Running command in Docker Compose service: $BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN"

echo "TODO"

exit 1

run_docker_compose "run $BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN \"$BUILDKITE_COMMAND\""
