#!/bin/bash
set -ueo pipefail

override_file="docker-compose.buildkite-${BUILDKITE_BUILD_NUMBER}-override.yml"
build_images=()
build_params=()

if [[ "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_COLLAPSE_LOGS:-false}" = "true" ]]; then
  group_type="---"
else
  group_type="+++"
fi

if [[ "$(plugin_read_config BUILDKIT "true")" == "true" ]]; then
  export DOCKER_BUILDKIT=1
  export COMPOSE_DOCKER_CLI_BUILD=1
  export BUILDKIT_PROGRESS=plain
fi

get_caches_for_service() {
  local service="$1"

  # Read any cache-from parameters provided
  # If no-cache is set skip pulling the cache-from images
  if [[ "$(plugin_read_config NO_CACHE "false")" == "false" ]] ; then
    for line in $(plugin_read_list CACHE_FROM) ; do
      IFS=':' read -r -a tokens <<< "$line"
      service_name=${tokens[0]}
      service_image=$(IFS=':'; echo "${tokens[*]:1}")

      if [ "${service_name}" == "${service}" ]; then
        echo "$service_image"
      fi
    done
  fi
}

# Run through all images in the build property, either a single item or a list
# and build up a list of service name, image name and optional cache-froms to
# write into a docker-compose override file
for service_name in $(plugin_read_list BUILD) ; do
  target="$(plugin_read_config TARGET "")"
  image_name="" # no longer used here

  cache_from=()
  cache_length=0
  
  for cache_line in $(get_caches_for_service "$service_name"); do
    cache_from+=("$cache_line")
    cache_length=$((cache_length + 1))
  done

  if [[ -n "${target}" ]] || [[ "${cache_length:-0}" -gt 0 ]]; then
    build_images+=("$service_name" "${image_name}" "${target}" "${cache_length}")

    if [[ "${cache_length:-0}" -gt 0 ]]; then
      build_images+=("${cache_from[@]}")
    fi
  fi
done

if [[ ${#build_images[@]} -gt 0 ]] ; then
  echo "~~~ :docker: Creating a modified docker-compose config"
  build_image_override_file "${build_images[@]}" | tee "$override_file"
fi

services=()

# Parse the list of services to build into an array
while read -r line ; do
  [[ -n "$line" ]] && services+=("$line")
done <<< "$(plugin_read_list BUILD)"

if [[ -f "${override_file}" ]]; then
  build_params+=(-f "${override_file}")
fi

build_params+=(build)

if [[ ! "$(plugin_read_config SKIP_PULL "false")" == "true" ]] ; then
  build_params+=(--pull)
fi

if [[ "$(plugin_read_config NO_CACHE "false")" == "true" ]] ; then
  build_params+=(--no-cache)
fi

if [[ "$(plugin_read_config BUILD_PARALLEL "false")" == "true" ]] ; then
  build_params+=(--parallel)
fi

# Parse the list of secrets to pass on to build command
while read -r line ; do
  [[ -n "$line" ]] && build_params+=("--secret" "$line")
done <<< "$(plugin_read_list SECRETS)"

if [[ "$(plugin_read_config SSH "false")" != "false" ]] ; then
  if [[ "${DOCKER_BUILDKIT:-}" != "1" && "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLI_VERSION:-2}" != "2" ]]; then
    echo "🚨 You can not use the ssh option if you are not using buildkit"
    exit 1
  fi

  SSH_CONTEXT="$(plugin_read_config SSH)"
  if [[ "${SSH_CONTEXT}" == "true" ]]; then
    # ssh option was a boolean
    SSH_CONTEXT='default'
  fi
  build_params+=(--ssh "${SSH_CONTEXT}")
fi

while read -r arg ; do
  [[ -n "${arg:-}" ]] && build_params+=("--build-arg" "${arg}")
done <<< "$(plugin_read_list ARGS)"

echo "${group_type} :docker: Building services ${services[*]}"
run_docker_compose "${build_params[@]}" "${services[@]}"