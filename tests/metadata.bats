#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'
load '../lib/shared'
load '../lib/metadata'

@test "Image service tag with default config" {
  run prebuilt_image_meta_data_key "service"

  assert_success
  assert_output "built-image-tag-service"
}

@test "Image service tag with single non-default config" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG=tests/composefiles/docker-compose.v2.0.yml

  run prebuilt_image_meta_data_key "service"

  assert_success
  assert_output "built-image-tag-service-tests/composefiles/docker-compose.v2.0.yml"
}

@test "Image service tag with multiple non-default config" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG_0=tests/composefiles/docker-compose.v2.0.yml
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG_1=tests/composefiles/docker-compose.v2.1.yml

  run prebuilt_image_meta_data_key "service"

  assert_success
  assert_output "built-image-tag-service-tests/composefiles/docker-compose.v2.0.yml-tests/composefiles/docker-compose.v2.1.yml"
}