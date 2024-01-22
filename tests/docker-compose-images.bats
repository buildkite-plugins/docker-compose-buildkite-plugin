#!/usr/bin/env bats

# export DOCKER_COMPOSE_STUB_DEBUG=/dev/tty
# export DOCKER_STUB_DEBUG=/dev/tty

load "${BATS_PLUGIN_PATH}/load.bash"
load '../lib/shared'
load '../lib/push'

setup() {
  export HIDE_PROMPT=1
}

@test "Image for compose service with an image in config" {
  stub docker-compose \
    "-f docker-compose.yml -p buildkite config : cat $PWD/tests/composefiles/docker-compose.config.v3.2.yml"

  run compose_image_for_service "app"

  assert_success
  assert_output "somewhere.dkr.ecr.some-region.amazonaws.com/blah"

  unstub docker-compose
}

@test "Image for compose service with a service with hyphens in the name" {
  stub docker-compose \
    "-f docker-compose.yml -p buildkite config : cat $PWD/tests/composefiles/docker-compose.config.with.hyphens.yml"

  run compose_image_for_service "foo-db"

  assert_success
  assert_output "postgres:9.4"

  unstub docker-compose
}

@test "Image for compose service without an image in config" {
  stub docker-compose \
    "-f docker-compose.yml -p buildkite config : cat $PWD/tests/composefiles/docker-compose.config.v3.2.yml"

  run compose_image_for_service "helper"

  assert_success
  assert_output ""

  unstub docker-compose
}

@test "Default image for compose service" {
  run default_compose_image_for_service "helper"

  assert_success
  assert_output "buildkite_helper"
}

@test "Default image for compose v2 service" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLI_VERSION=2

  run default_compose_image_for_service "helper"

  assert_success
  assert_output "buildkite-helper"
}

@test "Default image for compose v2 service using compatibility" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLI_VERSION=2
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_COMPATIBILITY=true

  run default_compose_image_for_service "helper"

  assert_success
  assert_output "buildkite_helper"
}

@test "Default image for compose service using compatibility" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_COMPATIBILITY=true

  run default_compose_image_for_service "helper"

  assert_success
  assert_output "buildkite_helper"
}
