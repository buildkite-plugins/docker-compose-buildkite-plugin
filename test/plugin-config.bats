#!/usr/bin/env bats

load '../lib/shared'

@test "Read existing config without default" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=llamas
  run plugin_read_config 'RUN'
  [ "$status" -eq 0 ]
  [ "$output" == "llamas" ]
}

@test "Read existing config with default" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=llamas
  run plugin_read_config 'RUN' 'blah'
  [ "$status" -eq 0 ]
  [ "$output" == "llamas" ]
}

@test "Read non-existant config without default" {
  run plugin_read_config 'RUN'
  [ "$status" -eq 0 ]
  [ "$output" == "" ]
}

@test "Read non-existant config with default" {
  run plugin_read_config 'RUN' 'blah'
  [ "$status" -eq 0 ]
  [ "$output" == "blah" ]
}