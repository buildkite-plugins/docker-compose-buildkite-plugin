#!/bin/bash

compose_image_for_service() {
  local service="$1"
  local image=""

  image=$(run_docker_compose config \
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

# Extracts the image digest from a pushed image and stores it in Buildkite metadata
store_image_digest() {
  local namespace="$1"
  local service="$2"
  local image="$3"
  
  # Skip if push-metadata is disabled
  if [ "$(plugin_read_config PUSH_METADATA "true")" != "true" ]; then
    return 0
  fi
  
  # Get the image digest
  local digest
  digest=$(docker inspect --format='{{range .RepoDigests}}{{.}}{{"\n"}}{{end}}' "$image" 2>/dev/null | head -1 | cut -d'@' -f2)
  
  if [ -n "$digest" ]; then
    # Store digest in Buildkite metadata using the same namespace as other metadata
    local digest_key="built-image-digest-${service}"
    plugin_set_metadata "$namespace" "$digest_key" "$digest"
    echo "~~~ :information_source: Stored image digest for $service: $digest"
  else
    echo "--- :warning: Could not retrieve digest for image: $image"
  fi
}

# Retrieves a stored image digest for a service name
get_image_digest() {
  local namespace="$1"
  local service="$2"
  local digest_key="built-image-digest-${service}"
  
  plugin_get_metadata "$namespace" "$digest_key"
}
