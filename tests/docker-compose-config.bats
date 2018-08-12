#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'
load '../lib/shared'

@test "Read docker-compose config when none exists" {
  run docker_compose_config_files

  assert_success
  assert_output "docker-compose.yml"
}

@test "Read docker-compose config when there are several" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG_0="llamas1.yml"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG_1="llamas2.yml"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG_2="llamas3.yml"
  run docker_compose_config_files

  assert_success
  assert_equal "${lines[0]}" "llamas1.yml"
  assert_equal "${lines[1]}" "llamas2.yml"
  assert_equal "${lines[2]}" "llamas3.yml"
}

@test "Read colon delimited config files" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG="llamas1.yml:llamas2.yml"
  run docker_compose_config_files

  assert_success
  assert_equal "${lines[0]}" "llamas1.yml"
  assert_equal "${lines[1]}" "llamas2.yml"
}

@test "Read version from docker-compose v2.0 file with whitespace around the version" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG="tests/composefiles/docker-compose.v2.0.with-version-whitespace.yml"
  run docker_compose_config_version
  assert_success
  assert_output "2"
}

@test "Read version from docker-compose v2.0 file" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG="tests/composefiles/docker-compose.v2.0.yml"
  run docker_compose_config_version
  assert_success
  assert_output "2"
}

@test "Read version from docker-compose v2.1 file" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG="tests/composefiles/docker-compose.v2.1.yml"
  run docker_compose_config_version
  assert_success
  assert_output "2.1"
}

@test "Whether docker-compose supports cache_from directive" {
  run docker_compose_supports_cache_from ""
  assert_failure

  run docker_compose_supports_cache_from "1.0"
  assert_failure

  run docker_compose_supports_cache_from "2"
  assert_failure

  run docker_compose_supports_cache_from "2.1"
  assert_failure

  run docker_compose_supports_cache_from "2.2"
  assert_success

  run docker_compose_supports_cache_from "2.3"
  assert_success

  run docker_compose_supports_cache_from "3"
  assert_failure

  run docker_compose_supports_cache_from "3.1"
  assert_failure

  run docker_compose_supports_cache_from "3.2"
  assert_success

  run docker_compose_supports_cache_from "3.3"
  assert_success
}
