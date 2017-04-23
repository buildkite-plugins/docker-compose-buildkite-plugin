#!/usr/bin/env bats

load '../lib/shared'
load '../lib/run'

@test "Default cleanup of docker-compose" {
  run_docker_compose() {
    echo "$@"
  }
  run compose_cleanup
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "kill" ]
  [ "${lines[1]}" = "rm --force -v" ]
  [ "${lines[2]}" = "down --volumes" ]
}

@test "Possible to skip volume destruction in docker-compose cleanup" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_LEAVE_VOLUMES=1
  run_docker_compose() {
    echo "$@"
  }
  run compose_cleanup
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "kill" ]
  [ "${lines[1]}" = "rm --force" ]
  [ "${lines[2]}" = "down" ]
}