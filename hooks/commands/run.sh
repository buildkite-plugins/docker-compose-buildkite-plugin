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
  echo "~~~ :docker: Cleaning up Docker containers"

  run_docker_compose "kill" || true
  run_docker_compose "rm --force -v" || true

  # This isn't cleaned up by compose, so we have to do it ourselves
  local adhoc_run_container_name="${COMPOSE_SERVICE_NAME}_run_1"
  buildkite-run "docker rm -f -v $(docker_compose_container_name \"$adhoc_run_container_name\")" || true
}

trap compose_force_cleanup EXIT

try_image_restore_from_docker_repository() {
  local tag=$(buildkite-agent meta-data get "$(build_meta_data_image_tag_key "$COMPOSE_SERVICE_NAME")" 2>/dev/null)

  if [[ ! -z "$tag" ]]; then
    echo "~~~ :docker: Pulling docker image $tag"

    buildkite-run "docker pull \"$tag\""

    # Remove the image on exit
    trap "docker rmi -f $tag || true" EXIT

    echo "~~~ :docker: Creating a modified Docker Compose config"

    # TODO: Fix this el-dodgo method
    local escaped_tag_for_sed=$(echo "$tag" | sed -e 's/[\/&]/\\&/g')
    buildkite-run "sed -i.orig \"s/build: \./image: $escaped_tag_for_sed/\" \"$(docker_compose_config_file)\""
  fi
}

try_image_restore_from_docker_repository

echo "+++ :docker: Running command in Docker Compose service: $COMPOSE_SERVICE_NAME"

run_docker_compose "run --rm \"$COMPOSE_SERVICE_NAME\" \"$BUILDKITE_COMMAND\""
