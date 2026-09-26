#!/bin/bash

# Prints the `image` of the given service from the resolved Compose config.
# An already-resolved config (the output of `docker compose config`) can be
# passed as the second argument to avoid re-running it for every service.
compose_image_for_service() {
  local service="$1"
  local compose_config="${2:-}"
  local image=""

  if [[ -z "$compose_config" ]] ; then
    compose_config=$(run_docker_compose config)
  fi

  image=$(printf '%s\n' "$compose_config" \
    | grep -E "^(  [._[:alnum:]-]+:|    image:)" \
    | grep -E "(  ${service}:)" -A 1 \
    | grep -oE '  image: (.+)' \
    | awk '{print $2}')

  echo "$image"
}

default_compose_image_for_service() {
  local service="$1"
  
  local separator="-"
  if [[ "$(plugin_read_config CLI_VERSION "2")" == "1" ]] || [[ "$(plugin_read_config COMPATIBILITY "false")" == "true" ]] ; then
    separator="_"
  fi

  printf '%s%s%s\n' "$(docker_compose_project_name)" "$separator" "$service"
}

docker_image_exists() {
  local image="$1"
  plugin_prompt_and_run docker image inspect "${image}" &> /dev/null
}
