#!/bin/bash

build_service_name="$(plugin_read_config BUILD)"
build_image_repository="$(plugin_read_config IMAGE_REPOSITORY)"
build_image_name_default="${BUILDKITE_PIPELINE_SLUG}-${build_service_name}-build-${BUILDKITE_BUILD_NUMBER}"
build_image_name="$(plugin_read_config IMAGE_NAME "$build_image_name_default")"
override_file="docker-compose.buildkite-${build_service_name}-override.yml"
config_version="$(docker_compose_config_version)"

if [[ ! -z "$build_image_repository" ]]; then
  build_image_name="${build_image_repository}:${build_image_name}"
fi

echo "~~~ :docker: Creating a modified Docker Compose config"
build_image_override_file "$config_version" "$build_service_name" "$build_image_name" \
  | tee "$override_file"

echo "+++ :docker: Building Docker Compose images for service $build_service_name"
run_docker_compose -f "$override_file" build "$build_service_name"

if [[ ! -z "$build_image_repository" ]]; then
  echo "~~~ :docker: Pushing image to $build_image_repository"
  plugin_prompt_and_must_run docker push "$build_image_name"
  plugin_set_build_image_metadata "$build_service_name" "$build_image_name"
fi
