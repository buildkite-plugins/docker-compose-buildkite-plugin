#!/bin/bash

compose_cleanup() {
  local FAILURES=0

  if [[ "$(plugin_read_config GRACEFUL_SHUTDOWN 'false')" == "false" ]]; then
    SIGNAL="kill"
  else
    SIGNAL="stop"
  fi

  # Send all containers the corresponding signal
  if ! run_docker_compose "${SIGNAL}"; then
    FAILURES=$((FAILURES + 1))
  fi

  # `compose down` doesn't support force removing images
  RM_PARAMS=(rm --force)
  if [[ "$(plugin_read_config LEAVE_VOLUMES 'false')" == "false" ]]; then
    RM_PARAMS+=(-v)
  fi

  if ! run_docker_compose "${RM_PARAMS[@]}"; then
    FAILURES=$((FAILURES + 1))
  fi

  # Stop and remove all the linked services and network
  DOWN_PARAMS=(down --remove-orphans)
  if [[ "$(plugin_read_config LEAVE_VOLUMES 'false')" == "false" ]]; then
    DOWN_PARAMS+=(--volumes)
  fi

  if ! run_docker_compose "${DOWN_PARAMS[@]}"; then
    FAILURES=$((FAILURES + 1))
  fi

  return "${FAILURES}"
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
# versions do. So we add very simple support for the common and basic case.
#
# "./foo:/foo" => "/buildkite/builds/.../foo:/foo"
expand_relative_volume_path() {
  local path

  if [[ "$(plugin_read_config EXPAND_VOLUME_VARS 'false')" == "true" ]]; then
    path=$(eval echo "$1")
  else
    path="$1"
  fi

  local pwd="$PWD"

  # docker-compose's -v expects native paths on windows, so convert back.
  #
  # "/c/Users/..." => "C:\Users\..."
  if is_windows ; then
    pwd="$(cygpath -w "$PWD")"
  fi



  echo "${path/.\//$pwd/}"
}

# Prints information about the failed containers.
function print_failed_container_information() {
  # Get list of failed containers
  containers=()
  while read -r container ; do
    [[ -n "$container" ]] && containers+=("$container")
  done <<< "$(docker_ps_by_project -q)"

  failed_containers=()
  if [[ 0 != "${#containers[@]}" ]] ; then
    while read -r container ; do
      [[ -n "$container" ]] && failed_containers+=("$container")
    done <<< "$(docker inspect -f '{{if ne 0 .State.ExitCode}}{{.Name}}.{{.State.ExitCode}}{{ end }}' \
      "${containers[@]}")"
  fi

  if [[ 0 != "${#failed_containers[@]}" ]] ; then
    echo "+++ :warning: Some containers had non-zero exit codes"
    docker_ps_by_project \
      --format 'table {{.Label "com.docker.compose.service"}}\t{{ .ID }}\t{{ .Status }}'
  fi
}

# Uploads the container's logs, respecting the `UPLOAD_CONTAINER_LOGS` option
function upload_container_logs() {
  run_service="$1"

  if [[ -n "${BUILDKITE_AGENT_ACCESS_TOKEN:-}" ]] ; then
    check_linked_containers_and_save_logs \
      "$run_service" "docker-compose-logs" \
      "$(plugin_read_config UPLOAD_CONTAINER_LOGS "on-error")"

    if [[ -d "docker-compose-logs" ]] && test -n "$(find docker-compose-logs/ -maxdepth 1 -name '*.log' -print)"; then
      echo "~~~ Uploading linked container logs"
      buildkite-agent artifact upload "docker-compose-logs/*.log"
    fi
  fi
}
