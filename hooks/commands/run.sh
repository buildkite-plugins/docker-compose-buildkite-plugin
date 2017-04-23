#!/bin/bash

run_service_name="$(plugin_read_config RUN)"
override_file="docker-compose.buildkite-${run_service_name}-override.yml"

compose_force_cleanup() {
  echo "~~~ :docker: Cleaning up Docker containers"

  # Send them a friendly kill
  run_docker_compose kill || true

  # `compose down` doesn't support force removing images
  if [[ "$(plugin_read_config LEAVE_VOLUMES 'false')" == "false" ]]; then
    run_docker_compose rm --force -v || true
  else
    run_docker_compose rm --force || true
  fi

  # Stop and remove all the linked services and network
  if [[ "$(plugin_read_config LEAVE_VOLUMES 'false')" == "false" ]]; then
    run_docker_compose down --volumes || true
  else
    run_docker_compose down || true
  fi
}

trap compose_force_cleanup EXIT

try_image_restore_from_docker_repository() {
  local version
  local image

  image=$(plugin_get_build_image_metadata "$run_service_name")

  if [[ -n "$image" ]] ; then
    echo "~~~ :docker: Pulling docker image $image"
    plugin_prompt_and_must_run docker pull "$image"

    version=$(docker_compose_config_version)

    echo "~~~ :docker: Creating a modified Docker Compose config ($version)"
    build_image_override_file "$version" "$run_service_name" "$image" \
      | tee "$override_file"
  fi
}

try_image_restore_from_docker_repository

echo "+++ :docker: Running command in Docker Compose service: $run_service_name"

# $BUILDKITE_COMMAND needs to be unquoted because:
#   docker-compose run "app" "go test"
# does not work whereas the follow does:
#   docker-compose run "app" go test

if [[ -f "$override_file" ]]; then
  run_docker_compose -f "$override_file" run "$run_service_name" $BUILDKITE_COMMAND
else
  run_docker_compose run "$run_service_name" $BUILDKITE_COMMAND
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