#!/bin/bash

COMPOSE_SERVICE_NAME="$BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN"
COMPOSE_SERVICE_OVERRIDE_FILE="docker-compose.buildkite-$COMPOSE_SERVICE_NAME-override.yml"

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

  # `compose down` doesn't support force removing images, so we use `rm --force`
  if [[ "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_LEAVE_VOLUMES:-false}" == "false" ]]; then
    run_docker_compose rm --force -v || true
  else
    run_docker_compose rm --force || true
  fi

  # Stop and remove all the linked services and network
  if [[ "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_LEAVE_VOLUMES:-false}" == "false" ]]; then
    run_docker_compose down --volumes || true
  else
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

    build_image_override_file "$COMPOSE_SERVICE_NAME" "$tag" \
      | tee "$COMPOSE_SERVICE_OVERRIDE_FILE"
  fi
}

try_image_restore_from_docker_repository

echo "+++ :docker: Running command in Docker Compose service: $COMPOSE_SERVICE_NAME"

# $BUILDKITE_COMMAND needs to be unquoted because:
#   docker-compose run "app" "go test"
# does not work whereas the follow does:
#   docker-compose run "app" go test

if [[ -f "$COMPOSE_SERVICE_OVERRIDE_FILE" ]]; then
  run_docker_compose -f "$COMPOSE_SERVICE_OVERRIDE_FILE" run "$COMPOSE_SERVICE_NAME" $BUILDKITE_COMMAND
else
  run_docker_compose run "$COMPOSE_SERVICE_NAME" $BUILDKITE_COMMAND
fi

exitcode=$?

if [[ $exitcode -ne 0 ]] ; then
  echo "^^^ +++"
  echo "+++ :warning: Failed to run command, exited with $exitcode"
fi

list_linked_containers() {
  for container_id in $(HIDE_PROMPT=1 run_docker_compose ps -q); do
    docker inspect --format='{{.Name}}' "$container_id"
  done
}

check_linked_containers() {
  local logdir="$1"
  local cmdexit="$2"

  mkdir -p "$logdir"

  for container_name in $(list_linked_containers); do
    container_exit_code=$(docker inspect --format='{{.State.ExitCode}}' "$container_name")

    if [[ $container_exit_code -ne 0 ]] ; then
      echo "+++ :warning: Linked container $container_name exited with $container_exit_code"
    fi

    # Capture logs if the linked container failed OR if the main command failed
    if [[ $container_exit_code -ne 0 ]] || [[ $cmdexit -ne 0 ]] ; then
      plugin_prompt_and_run docker logs --timestamps --tail 500 "$container_name"
      docker logs -t "$container_name" > "${logdir}/${container_name}.log"
    fi
  done
}

echo "~~~ Checking linked containers"
check_linked_containers "docker-compose-logs" "$exitcode"

echo "~~~ Uploading container logs as artifacts"
buildkite-agent artifact upload "docker-compose-logs/*.log"

exit $exitcode