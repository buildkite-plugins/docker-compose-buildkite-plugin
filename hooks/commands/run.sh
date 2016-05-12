#!/bin/bash

COMPOSE_SERVICE_NAME="$BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN"

: "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_USER:=$(id -u)}"

check_required_args() {
  if [[ -z "${BUILDKITE_COMMAND:-}" ]]; then
    echo "No command to run. Did you provide a 'command' for this step?"
    exit 1
  fi
}

check_required_args

compose_force_cleanup() {
  echo "~~~ :docker: Cleaning up Docker containers"

  if [[ "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_LEAVE_VOLUMES:-false}" == "true" ]]; then
    local remove_volume_flag=""
  else
    local remove_volume_flag="-v"
  fi

  # Send them a friendly kill
  run_docker_compose "kill" || true

  local docker_compose_version
  docker_compose_version=$(run_docker_compose --version)

  if [[ "$docker_compose_version" == *1.4* || "$docker_compose_version" == *1.5* || "$docker_compose_version" == *1.6* ]]; then
    # There's no --all flag to remove adhoc containers
    run_docker_compose "rm --force $remove_volume_flag" || true

    # So now we remove the adhoc container
    # This isn't cleaned up by compose, so we have to do it ourselves
    local adhoc_run_container_name="${COMPOSE_SERVICE_NAME}_run_1"
    buildkite-run "docker rm -f $remove_volume_flag $(docker_compose_container_name \""$adhoc_run_container_name"\")" || true
  else
    # `compose down` doesn't support force removing images, so we use `rm --force`
    run_docker_compose "rm --force --all $remove_volume_flag" || true

    # Stop and remove all the linked services and network
    run_docker_compose "down" || true
  fi
}

trap compose_force_cleanup EXIT

try_image_restore_from_docker_repository() {
  local tag
  tag=$(buildkite-agent meta-data get "$(build_meta_data_image_tag_key "$COMPOSE_SERVICE_NAME")" 2>/dev/null)

  if [[ ! -z "$tag" ]]; then
    echo "~~~ :docker: Pulling docker image $tag"

    buildkite-run "docker pull \"$tag\""

    echo "~~~ :docker: Creating a modified Docker Compose config"

    # TODO: Fix this el-dodgo method
    local escaped_tag_for_sed
    escaped_tag_for_sed=$(echo "$tag" | sed -e 's/[\/&]/\\&/g')
    buildkite-run "sed -i.orig \"s/build: \./image: $escaped_tag_for_sed/\" \"$(docker_compose_config_file)\""
  fi
}

try_image_restore_from_docker_repository

echo "+++ :docker: Running command in Docker Compose service: $COMPOSE_SERVICE_NAME"

run_docker_compose "run -u \"$BUILDKITE_PLUGIN_DOCKER_COMPOSE_USER\" \"$COMPOSE_SERVICE_NAME\" \"$BUILDKITE_COMMAND\""
