#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"
load '../lib/shared'
load '../lib/run'

setup () {
  run_docker_compose() {
    # shellcheck disable=2317 # funtion used by loaded scripts
    stubbed_run_docker_compose "$@"
  }
}

@test "Default cleanup of docker-compose" {
  stub stubbed_run_docker_compose \
    "kill : echo \$@" \
    "rm --force -v : echo \$@" \
    "down --remove-orphans --volumes : echo \$@"

  run compose_cleanup

  assert_success
  assert_equal "${lines[0]}" "kill"
  assert_equal "${lines[1]}" "rm --force -v"
  assert_equal "${lines[2]}" "down --remove-orphans --volumes"

  unstub stubbed_run_docker_compose
}

@test "Possible to gracefully shutdown containers in docker-compose cleanup" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_GRACEFUL_SHUTDOWN=1
  stub stubbed_run_docker_compose \
    "stop : echo \$@" \
    "rm --force -v : echo \$@" \
    "down --remove-orphans --volumes : echo \$@"

  run compose_cleanup

  assert_success
  assert_equal "${lines[0]}" "stop"
  assert_equal "${lines[1]}" "rm --force -v"
  assert_equal "${lines[2]}" "down --remove-orphans --volumes"

  unstub stubbed_run_docker_compose
}

@test "Possible to skip volume destruction in docker-compose cleanup" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_LEAVE_VOLUMES=1

  stub stubbed_run_docker_compose \
    "kill : echo \$@" \
    "rm --force : echo \$@" \
    "down --remove-orphans : echo \$@"

  run compose_cleanup

  assert_success
  assert_equal "${lines[0]}" "kill"
  assert_equal "${lines[1]}" "rm --force"
  assert_equal "${lines[2]}" "down --remove-orphans"

  unstub stubbed_run_docker_compose
}

@test "cleanup returns failure on kill failure" {
  stub stubbed_run_docker_compose \
    "kill : exit 1" \
    "rm --force -v : echo \$@" \
    "down --remove-orphans --volumes : echo \$@"

  run compose_cleanup

  assert_failure 1

  assert_equal "${lines[0]}" "rm --force -v"
  assert_equal "${lines[1]}" "down --remove-orphans --volumes"

  unstub stubbed_run_docker_compose
}

@test "cleanup returns failure on rm failure" {
  stub stubbed_run_docker_compose \
    "kill : echo \$@" \
    "rm --force -v : exit 1" \
    "down --remove-orphans --volumes : echo \$@"

  run compose_cleanup

  assert_failure 1

  assert_equal "${lines[0]}" "kill"
  assert_equal "${lines[1]}" "down --remove-orphans --volumes"

  unstub stubbed_run_docker_compose
}

@test "cleanup returns failure on down failure" {
  stub stubbed_run_docker_compose \
    "kill : echo \$@" \
    "rm --force -v : echo \$@" \
    "down --remove-orphans --volumes : exit 1"

  run compose_cleanup

  assert_failure 1

  assert_equal "${lines[0]}" "kill"
  assert_equal "${lines[1]}" "rm --force -v"

  unstub stubbed_run_docker_compose
}

@test "cleanup returns 2 failures on kill and down failure" {
  stub stubbed_run_docker_compose \
    "kill : exit 1" \
    "rm --force -v : echo \$@" \
    "down --remove-orphans --volumes : exit 1"

  run compose_cleanup

  assert_failure 2

  assert_output "rm --force -v"

  unstub stubbed_run_docker_compose
}
