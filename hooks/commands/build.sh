#!/bin/bash
set -ueo pipefail

image_repository="$(plugin_read_config IMAGE_REPOSITORY)"
pull_retries="$(plugin_read_config PULL_RETRIES "0")"
override_file="docker-compose.buildkite-${BUILDKITE_BUILD_NUMBER}-override.yml"
build_images=()

for line in $(plugin_read_list CACHE_FROM) ; do
  IFS=':' read -r -a tokens <<< "$line"
  service_name=${tokens[0]}
  service_image=$(IFS=':'; echo "${tokens[*]:1}")

  echo "~~~ :docker: Pulling cache image for $service_name"
  if retry "$pull_retries" plugin_prompt_and_run docker pull "$service_image" ; then
    printf -v "cache_from__${service_name}" %s "$service_image"
  else
    echo "!!! :docker: Pull failed. $service_image will not be used as a cache for $service_name"
  fi
done

for service_name in $(plugin_read_list BUILD) ; do
  image_name=$(build_image_name "${service_name}")

  if [[ -n "$image_repository" ]]; then
    image_name="${image_repository}:${image_name}"
  fi

  build_images+=("$service_name" "$image_name")

  cache_key="cache_from__${service_name}"
  if [[ -n "${!cache_key-}" ]]; then
    build_images+=("${!cache_key}")
  else
    build_images+=("")
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

build_args=(--pull)

if [[ "$(plugin_read_config NO_CACHE "false")" == "true" ]] ; then
  build_args+=(--no-cache)
fi

echo "+++ :docker: Building services ${services[*]}"
run_docker_compose -f "$override_file" build "${build_args[@]}" "${services[@]}"

if [[ -n "$image_repository" ]]; then
  echo "~~~ :docker: Pushing built images to $image_repository"
  run_docker_compose -f "$override_file" push "${services[@]}"

  while [[ ${#build_images[@]} -gt 0 ]] ; do
    set_prebuilt_image "${build_images[0]}" "${build_images[1]}"
    build_images=("${build_images[@]:3}")
  done
fi
