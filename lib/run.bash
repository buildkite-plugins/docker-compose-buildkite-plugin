#!/bin/bash

kill_or_wait_for_stop() {

  if [[ "$(plugin_read_config GRACEFUL_SHUTDOWN 'false')" == "true" ]]; then
    # This will block until the container exits
    run_docker_compose wait
    container_exit_code=$?
  fi

  # This will kill the container if it hasn't exited yet
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

compose_cleanup() {
  kill_or_wait_for_stop &
  
  # No need to call kill directly for GRACEFUL_SHUTDOWN == false since rm --force will send the same kill signal
  if [[ "$(plugin_read_config GRACEFUL_SHUTDOWN 'false')" == "true" ]]; then
    # Send all containers a friendly SIGTERM, followed by a SIGKILL after exceeding the stop_grace_period
    run_docker_compose stop || true
  fi
}

# Checks for failed containers and writes logs for them the the provided dir
check_linked_containers_and_save_logs() {
  local service="$1"
  local logdir="$2"
  local uploadlogs="$3"
  local uploadall="false"

  if [[ "$uploadlogs" =~ ^(false|off|0|never)$ ]]; then
    # Skip all if we are not uploading logs
    return
  elif [[ "$uploadlogs" =~ ^(true|on|1|always)$ ]]; then
    uploadall="true"
  fi

  [[ -d "$logdir" ]] && rm -rf "$logdir"
  mkdir -p "$logdir"

  # Get list of container if to service labels
  containers=()
  while IFS=$'\n' read -r container ; do
    [[ -n "$container" ]] && containers+=("$container")
  done < <(docker_ps_by_project --format '{{.ID}}\t{{.Label "com.docker.compose.service"}}')

  # Iterate over containers, handling empty container array as a possibility
  for line in "${containers[@]+"${containers[@]}"}" ; do
    # Split tab-delimited tokens into service name and container id
    service_name="$(cut -d$'\t' -f2 <<<"$line")"
    service_container_id="$(cut -d$'\t' -f1 <<<"$line")"

    # Skip uploading logs for the primary service container
    if [[ "$service_name" == "$service" ]] ; then
      continue
    fi

    service_exit_code="$(docker inspect --format='{{.State.ExitCode}}' "$service_container_id")"

    # Capture logs if the linked container failed
    if [[ "$service_exit_code" -ne 0 ]] ; then
      echo "+++ :warning: Linked service $service_name exited with $service_exit_code"
      plugin_prompt_and_run docker logs --timestamps --tail 5 "$service_container_id"
      docker logs -t "$service_container_id" &>"${logdir}/${service_name}.log"
    elif $uploadall; then
      docker logs -t "$service_container_id" &>"${logdir}/${service_name}.log"
    fi
  done
}

# docker-compose's -v arguments don't do local path expansion like the .yml
# versions do. So we add very simple support, for the common and basic case.
#
# "./foo:/foo" => "/buildkite/builds/.../foo:/foo"
expand_relative_volume_path() {
  local path="$1"
  local pwd="$PWD"

  # docker-compose's -v expects native paths on windows, so convert back.
  #
  # "/c/Users/..." => "C:\Users\..."
  if is_windows ; then
    pwd="$(cygpath -w "$PWD")"
  fi

  echo "${path/.\//$pwd/}"
}
