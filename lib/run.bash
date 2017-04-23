
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

get_prebuilt_image_from_metadata() {
  local service_name="$1"
  plugin_get_build_image_metadata "$service_name"
}

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