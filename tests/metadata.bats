#!/usr/bin/env bats

# export BUILDKITE_AGENT_STUB_DEBUG=/dev/tty

load "${BATS_PLUGIN_PATH}/load.bash"
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

@test "Check if image exists in metadata before trying to retrieve" {
  # Only expect the 'exists' command to be called, not the 'get'
  stub buildkite-agent "meta-data exists docker-compose-plugin-built-image-tag-test : exit 1"

  run get_prebuilt_image "test"
  
  assert_failure
  unstub buildkite-agent
}

@test "Only get prebuilt image from metadata if 'exists' check returns true" {
  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-test : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-test : exit 0" 

  run get_prebuilt_image "test"
  
  assert_success
  assert_output --partial "buildkite-agent meta-data get docker-compose-plugin-built-image-tag-test"
  unstub buildkite-agent
}
