#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"
load '../lib/shared'

@test "Read existing config without default" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=llamas
  run plugin_read_config 'RUN'

  assert_success
  assert_output "llamas"
}

@test "Read existing config with default" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=llamas
  run plugin_read_config 'RUN' 'blah'

  assert_success
  assert_output "llamas"
}

@test "Read non-existant config without default" {
  run plugin_read_config 'RUN'

  assert_success
  assert_output ""
}

@test "Read non-existant config with default" {
  run plugin_read_config 'RUN' 'blah'

  assert_success
  assert_output "blah"
}