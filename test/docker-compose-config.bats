#!/usr/bin/env bats

load '../lib/shared'

@test "Read docker-compose config when none exists" {
  run docker_compose_config_files
  [ "$status" -eq 0 ]
  [ "$output" == "docker-compose.yml" ]
}

@test "Read the first docker-compose config when none exists" {
  run docker_compose_config_file
  [ "$status" -eq 0 ]
  [ "$output" == "docker-compose.yml" ]
}

@test "Read docker-compose config when there are several" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG_0="llamas1.yml"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG_1="llamas2.yml"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG_2="llamas3.yml"
  run docker_compose_config_files
  [ "$status" -eq 0 ]
  [ "${lines[0]}" == "llamas1.yml" ]
  [ "${lines[1]}" == "llamas2.yml" ]
  [ "${lines[2]}" == "llamas3.yml" ]
}

@test "Read the first docker-compose config when there are several" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG_0="llamas1.yml"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG_1="llamas2.yml"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG_2="llamas3.yml"
  run docker_compose_config_file
  [ "$status" -eq 0 ]
  [ "$output" == "llamas1.yml" ]
}

@test "Read colon delimited config files" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG="llamas1.yml:llamas2.yml"
  run docker_compose_config_files
  [ "$status" -eq 0 ]
  [ "${lines[0]}" == "llamas1.yml" ]
  [ "${lines[1]}" == "llamas2.yml" ]
}

@test "Read the first docker-compose config when there are colon delimited config files" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG="llamas1.yml:llamas2.yml"
  run docker_compose_config_file
  [ "$status" -eq 0 ]
  [ "${lines[0]}" == "llamas1.yml" ]
}
