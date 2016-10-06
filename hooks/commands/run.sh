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

  # Send them a friendly kill
  run_docker_compose kill || true

  local docker_compose_version=$(run_docker_compose --version)

  if [[ "$docker_compose_version" == *1.4* || "$docker_compose_version" == *1.5* || "$docker_compose_version" == *1.6* ]]; then
    # There's no --all flag to remove adhoc containers
    if [[ "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_LEAVE_VOLUMES:-false}" == "true" ]]; then
      run_docker_compose rm --force -v || true
    else
      run_docker_compose rm --force || true
    fi

    # So now we remove the adhoc container
    # This isn't cleaned up by compose, so we have to do it ourselves
    local adhoc_run_container_name="${COMPOSE_SERVICE_NAME}_run_1"
    plugin_prompt_and_run docker rm -f "$remove_volume_flag" "$(docker_compose_container_name "$adhoc_run_container_name")" || true
  else
    # `compose down` doesn't support force removing images, so we use `rm --force`
    if [[ "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_LEAVE_VOLUMES:-false}" == "true" ]]; then
      run_docker_compose rm --force --all -v || true
    else
      run_docker_compose rm --force --all || true
    fi

    # Stop and remove all the linked services and network
    run_docker_compose down || true
  fi
}

trap compose_force_cleanup EXIT

try_image_restore_from_docker_repository() {
  plugin_prompt buildkite-agent meta-data get "$(build_meta_data_image_tag_key "$COMPOSE_SERVICE_NAME")"
  local tag="$(buildkite-agent meta-data get "$(build_meta_data_image_tag_key "$COMPOSE_SERVICE_NAME")" 2>/dev/null)"

  if [[ ! -z "$tag" ]]; then
    echo "~~~ :docker: Pulling docker image $tag"

    plugin_prompt_and_must_run docker pull "$tag"

    echo "~~~ :docker: Creating a modified Docker Compose config"

    # TODO: Fix this el-dodgo method
    local escaped_tag_for_sed=$(echo "$tag" | sed -e 's/[\/&]/\\&/g')
    plugin_prompt_and_must_run sed -i.orig "s/build: \./image: $escaped_tag_for_sed/" "$BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG""
  fi
}

try_image_restore_from_docker_repository

echo "+++ :docker: Running command in Docker Compose service: $COMPOSE_SERVICE_NAME"

# $BUILDKITE_COMMAND needs to be unquoted because:
#   docker-compose run "app" "go test"
# does not work whereas the follow down:
#   docker-compose run "app" go test
run_docker_compose run "$COMPOSE_SERVICE_NAME" $BUILDKITE_COMMAND
