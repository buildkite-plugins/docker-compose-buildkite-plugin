#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'
load '../lib/shared'
load '../lib/run'

@test "Default cleanup of docker-compose" {
  run_docker_compose() {
    echo "$@"
  }
  run compose_cleanup

  assert_success
  assert_equal "${lines[0]}" "kill"
  assert_equal "${lines[1]}" "rm --force -v"
  assert_equal "${lines[2]}" "down --volumes"
}

@test "Possible to skip volume destruction in docker-compose cleanup" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_LEAVE_VOLUMES=1
  run_docker_compose() {
    echo "$@"
  }
  run compose_cleanup

  assert_success
  assert_equal "${lines[0]}" "kill"
  assert_equal "${lines[1]}" "rm --force"
  assert_equal "${lines[2]}" "down"
}