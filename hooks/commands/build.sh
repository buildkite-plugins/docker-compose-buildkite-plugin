#!/bin/bash
set -ueo pipefail

image_repository="$(plugin_read_config IMAGE_REPOSITORY)"
override_file="docker-compose.buildkite-${BUILDKITE_BUILD_NUMBER}-override.yml"
build_images=()

for service_name in $(plugin_read_list BUILD) ; do
  image_name=$(build_image_name "${service_name}")

  if [[ -n "$image_repository" ]]; then
    image_name="${image_repository}:${image_name}"
  fi

  build_images+=("$service_name" "$image_name")
done

if [[ ${#build_images[@]} -gt 0 ]] ; then
  echo "~~~ :docker: Creating a modified docker-compose config"
  build_image_override_file "${build_images[@]}" | tee "$override_file"
fi

services=( $(plugin_read_list BUILD) )

echo "+++ :docker: Building services ${services[*]}"
run_docker_compose -f "$override_file" build "${services[@]}"

if [[ -n "$image_repository" ]]; then
  echo "~~~ :docker: Pushing built images to $image_repository"
  run_docker_compose -f "$override_file" push "${services[@]}"

  while [[ ${#build_images[@]} -gt 0 ]] ; do
    plugin_set_metadata "built-image-tag-${build_images[0]}" "${build_images[1]}"
    build_images=("${build_images[@]:2}")
  done
fi
