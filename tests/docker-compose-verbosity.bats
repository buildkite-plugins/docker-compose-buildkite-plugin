#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'
load '../lib/shared'
load '../lib/run'

# export DOCKER_COMPOSE_STUB_DEBUG=/dev/tty

@test "docker-compose verbosity config unset" {
  stub docker-compose \
    "-f docker-compose.yml -p buildkite run tests : echo ran without verbose flag"

  run run_docker_compose run tests

  assert_success
  assert_output --partial "ran without verbose flag"
  unstub docker-compose
}

@test "docker-compose verbosity config set to 'true'" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_VERBOSE="true"

  stub docker-compose \
    "--verbose -f docker-compose.yml -p buildkite run tests : echo ran with verbose flag"

  run run_docker_compose run tests

  assert_success
  assert_output --partial "ran with verbose flag"
  unstub docker-compose
}

@test "docker-compose verbosity config set to 'false'" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_VERBOSE="false"

  stub docker-compose \
    "-f docker-compose.yml -p buildkite run tests : echo ran without verbose flag"

  run run_docker_compose run tests

  assert_success
  assert_output --partial "ran without verbose flag"
  unstub docker-compose
}
