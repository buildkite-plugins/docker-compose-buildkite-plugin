#!/bin/bash
set -ueo pipefail

image_repository="$(plugin_read_config IMAGE_REPOSITORY)"
pull_retries="$(plugin_read_config PULL_RETRIES "0")"
override_file="docker-compose.buildkite-${BUILDKITE_BUILD_NUMBER}-override.yml"
build_images=()
declare -A cache_from

for line in $(plugin_read_list CACHE_FROM) ; do
  IFS=':' read -a tokens <<< "$line"
  service_name=${tokens[0]}
  service_image=$(IFS=':'; echo "${tokens[*]:1}")

  echo "~~~ :docker: Pulling cache image for $service_name"
  if retry "$pull_retries" plugin_prompt_and_run docker pull "$service_image" ; then
    cache_from[$service_name]=$service_image
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

  if in_array $service_name ${!cache_from[@]} ; then
    build_images+=("${cache_from[$service_name]}")
  else
    build_images+=("")
  fi
done

if [[ ${#build_images[@]} -gt 0 ]] ; then
  echo "~~~ :docker: Creating a modified docker-compose config"
  build_image_override_file "${build_images[@]}" | tee "$override_file"
fi

services=( $(plugin_read_list BUILD) )

echo "+++ :docker: Building services ${services[*]}"
run_docker_compose -f "$override_file" build --pull "${services[@]}"

if [[ -n "$image_repository" ]]; then
  echo "~~~ :docker: Pushing built images to $image_repository"
  run_docker_compose -f "$override_file" push "${services[@]}"

  while [[ ${#build_images[@]} -gt 0 ]] ; do
    plugin_set_metadata "built-image-tag-${build_images[0]}" "${build_images[1]}"
    build_images=("${build_images[@]:3}")
  done
fi
