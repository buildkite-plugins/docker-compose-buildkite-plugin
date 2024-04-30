#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"
load '../lib/shared'
load '../lib/run'

setup () {
  run_docker_compose() {
    # shellcheck disable=2317 # funtion used by loaded scripts
    echo "$@"
  }
}

@test "Default cleanup of docker-compose" {
  run compose_cleanup

  assert_success
  assert_equal "${lines[0]}" "rm --force -v"
  assert_equal "${lines[1]}" "down --remove-orphans --volumes"
}

@test "Possible to gracefully shutdown containers in docker-compose cleanup" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_GRACEFUL_SHUTDOWN="true"
  run compose_cleanup

  assert_success
  assert_output --partial "wait"
  assert_equal "${lines[1]}" "exit code was 0"
  assert_equal "${lines[2]}" "rm --force -v"
  assert_equal "${lines[3]}" "down --remove-orphans --volumes"
}

@test "Possible to skip volume destruction in docker-compose cleanup" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_LEAVE_VOLUMES=1
  run compose_cleanup

  assert_success
  assert_equal "${lines[0]}" "rm --force"
  assert_equal "${lines[1]}" "down --remove-orphans"
}
