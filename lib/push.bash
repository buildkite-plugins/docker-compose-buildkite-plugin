#!/bin/bash

compose_image_for_service() {
  local service="$1"
  local image=""

  image=$(run_docker_compose config \
    | grep -E "^(  [._[:alnum:]-]+:|    image:)" \
    | grep -E "(  ${service}:)" -A 1 \
    | grep -oE '  image: (.+)' \
    | awk '{print $2}')

  if [[ -z "$image" ]] ; then
    default_compose_image_for_service "$service"
    return
  fi

  echo "$image"
}

compose_custom_tag_for_service() {
  local service="$1"
  # i.e., BUILDKITE_DOCKER_TAG_SERVICE_SERVICENAME
  if [[ -n $BUILDKITE_DOCKER_PUSH_TAG_SERVICE_${service^^} ]]; then
    echo $BUILDKITE_DOCKER_PUSH_TAG_SERVICE_${service^^}
  fi
}

compose_custom_tag() {
  local service="$1"
  local tag=""

  # First check if there's a tag specific to the service
  tag=$(compose_custom_tag_for_service $service)

  if [[ -n $tag ]]; then
    echo $tag
  elif [[ -n $BUILDKITE_DOCKER_PUSH_TAG ]]; then
    echo $BUILDKITE_DOCKER_PUSH_TAG
  fi
}

default_compose_image_for_service() {
  local service="$1"

  printf '%s_%s\n' "$(docker_compose_project_name)" "$service"
}

docker_image_exists() {
  local image="$1"
  plugin_prompt_and_run docker image inspect "${image}" &> /dev/null
}
