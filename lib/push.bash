#!/bin/bash

compose_image_for_service() {
  local service="$1"
  local image=""

  image=$(run_docker_compose config \
    | grep -E "^(  [_[:alnum:]-]+:|    image:)" \
    | grep -E "(  ${service}:)" -A 1 \
    | grep -oE '  image: (.+)' \
    | awk '{print $2}')

  if [[ -z "$image" ]] ; then
    default_compose_image_for_service "$service"
    return
  fi

  echo "$image"
}

default_compose_image_for_service() {
  local service="$1"

  printf '%s_%s\n' "$(docker_compose_project_name)" "$service"
}

docker_image_exists() {
  local image="$1"
  plugin_prompt_and_run docker image inspect "${image}" &> /dev/null
}
