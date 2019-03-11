#!/bin/bash

compose_cleanup() {
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

# Checks for failed containers and writes logs for them the the provided dir
check_linked_containers_and_save_logs() {
  local service="$1"
  local logdir="$2"
  local all_logs="$3"

  [[ -d "$logdir" ]] && rm -rf "$logdir"
  mkdir -p "$logdir"

  while read -r line; do
    if [[ -z "${line}" ]]; then
      # Skip empty lines
      continue
    fi

    service_name="$(cut -d$'\t' -f2 <<<"$line")"
    service_container_id="$(cut -d$'\t' -f1 <<<"$line")"

    if [[ "$service_name" == "$service" ]]; then
      continue
    fi

    service_exit_code="$(docker inspect --format='{{.State.ExitCode}}' "$service_container_id")"

    # Capture logs if the linked container failed
    if [[ "$service_exit_code" -ne 0 ]]; then
      echo "+++ :warning: Linked service $service_name exited with $service_exit_code"
      plugin_prompt_and_run docker logs --timestamps --tail 5 "$service_container_id"
      docker logs -t "$service_container_id" &>"${logdir}/${service_name}.log"
    elif [[ "$all_logs" == "true" && "$service_exit_code" -eq 0 ]]; then
      docker logs -t "$service_container_id" &>"${logdir}/${service_name}.log"
    fi
  done <<<"$(docker_ps_by_project --format '{{.ID}}\t{{.Label "com.docker.compose.service"}}')"
}

# docker-compose's -v arguments don't do local path expansion like the .yml
# versions do. So we add very simple support, for the common and basic case.
#
# "./foo:/foo" => "/buildkite/builds/.../foo:/foo"
expand_relative_volume_path() {
  local path="$1"
  echo "${path/.\//$PWD/}"
}
