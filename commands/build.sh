#!/bin/bash
set -ueo pipefail

pull_retries="$(plugin_read_config PULL_RETRIES "0")"
override_file="docker-compose.buildkite-${BUILDKITE_BUILD_NUMBER}-override.yml"
build_images=()
build_params=()

if [[ "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_COLLAPSE_LOGS:-false}" = "true" ]]; then
  group_type="---"
else
  group_type="+++"
fi

normalize_var_name() {
  local orig_value="$1"
  # POSIX variable names should match [a-zA-Z_][a-zA-Z0-9_]*
  # service names and the like also allow periods and dashes
  no_periods="${orig_value//./_}"
  no_dashes="${no_periods//-/_}"
  echo "${no_dashes}"
}

service_name_cache_from_var() {
  local service_name="$1"
  echo "cache_from__$(normalize_var_name "${service_name}")"
}

service_name_group_name_cache_from_var() {
  local service_name="$1"
  local group_index="$2"
  echo "group_cache_from__$(normalize_var_name "${service_name}")__$(normalize_var_name "${group_index}")"
}

count_of_named_array() {
  local tmp="$1[@]"
  local copy=( "${!tmp}" )
  echo "${#copy[@]}"
}

named_array_values() {
  local tmp="$1[@]"
  local copy=( "${!tmp}" )
  echo "${copy[@]}"
}

if [[ "$(plugin_read_config BUILDKIT "false")" == "true" ]]; then
  export DOCKER_BUILDKIT=1
  export COMPOSE_DOCKER_CLI_BUILD=1
  export BUILDKIT_PROGRESS=plain
fi

# Read any cache-from parameters provided and pull down those images first
# If no-cache is set skip pulling the cache-from images
if [[ "$(plugin_read_config NO_CACHE "false")" == "false" ]] ; then
  for line in $(plugin_read_list CACHE_FROM) ; do
    IFS=':' read -r -a tokens <<< "$line"
    service_name=${tokens[0]}
    service_image=$(IFS=':'; echo "${tokens[*]:1}")

    # The variable with this name will hold an array of group names:
    cache_image_name="$(service_name_cache_from_var "$service_name")"

    if [[ -z "${!cache_image_name+x}" ]]; then
      declare -a "$cache_image_name"
      cache_image_length=0
    else
      cache_image_length="$(count_of_named_array "${cache_image_name}")"
    fi

    declare "$cache_image_name+=( $cache_from_group_name )"
    # The variable with this name will hold the image for the this group
    # (based on index into the array of group names):
    cache_from_group_var="$(service_name_group_name_cache_from_var "$service_name" "${cache_image_length}")"
    printf -v "$cache_from_group_var" "%s" "$service_image"
  done
fi

# Run through all images in the build property, either a single item or a list
# and build up a list of service name, image name and optional cache-froms to
# write into a docker-compose override file
service_idx=0
for service_name in $(plugin_read_list BUILD) ; do
  service_idx=$((service_idx+1))
  target="$(plugin_read_config TARGET "")"
  image_name="" # no longer used here

  cache_from_var="$(service_name_cache_from_var "${service_name}")"
  if [[ -n "${!cache_from_var-}" ]]; then
    cache_from_length="$(count_of_named_array "${cache_from_var}")"
  else
    cache_from_length=0
  fi

  if [[ -n "${target}" ]] || [[ "${cache_from_length:-0}" -gt 0 ]]; then
    build_images+=("$service_name" "${image_name}" "${target}" "${cache_from_length}")

    for i in $(seq 0 "$((cache_from_length-1))"); do
      cache_from_group_var="$(service_name_group_name_cache_from_var "$service_name" "$i")"
      build_images+=("${!cache_from_group_var}")
    done
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
  if [[ "${DOCKER_BUILDKIT:-}" != "1" && "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLI_VERSION:-}" != "2" ]]; then
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