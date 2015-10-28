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

restore_image_from_artifact() {
  # Store as build meta-data
  local build_meta_data_key="$(build_meta_data_artifact_key "$COMPOSE_SERVICE_NAME")"

  local artifact_name="$(buildkite-run "buildkite-agent meta-data get \"$BUILD_META_DATA_ARTIFACT_KEY\"")"

  if [[ ! -z "$artifact_name" ]]; then
    echo "Docker image stored in artifact \"$artifact_name\""
  fi
}

echo "~~~ Running command in Docker Compose service: $BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN"

restore_image_from_artifact

echo "TODO"

exit 1

run_docker_compose "run $BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN \"$BUILDKITE_COMMAND\""
