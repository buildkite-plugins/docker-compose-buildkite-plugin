#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"
load '../lib/run'
load '../lib/shared'

# export DOCKER_PS_BY_PROJECT_STUB_DEBUG=/dev/tty
# export CHECK_LINKED_CONTAINERS_AND_SAVE_LOGS_STUB_DEBUG=/dev/tty
# export DOCKER_STUB_DEBUG=/dev/tty

setup () {
  function docker_ps_by_project() {
    # shellcheck disable=2317 # funtion used by loaded scripts
    cat tests/fixtures/id-service-multiple-services.txt
  }

  function plugin_prompt_and_run() {
    # shellcheck disable=2317 # funtion used by loaded scripts
    echo "ran plugin_prompt_and_run"
  }
}

@test "Upload log settings: on-error" {
  export LOG_DIR="docker-compose-logs"

  stub docker \
    "inspect --format={{.State.ExitCode}} 456456 : echo 1" \
    "logs -t 456456 : echo got logs for failed" \
    "inspect --format={{.State.ExitCode}} 789789 : echo 0"

  run check_linked_containers_and_save_logs \
    "main" "/tmp/docker-compose-logs" "on-error"

  assert_success
  assert_output --partial "ran plugin_prompt_and_run"

  unstub docker
}

@test "Upload log settings: always" {
  export LOG_DIR="docker-compose-logs"

  stub docker \
    "inspect --format={{.State.ExitCode}} 456456 : echo 1" \
    "logs -t 456456 : echo got logs for failed" \
    "inspect --format={{.State.ExitCode}} 789789 : echo 0" \
    "logs -t 789789 : echo got logs for failed"

  run check_linked_containers_and_save_logs \
    "main" "/tmp/docker-compose-logs" "always"

  assert_success
  assert_output --partial "ran plugin_prompt_and_run"

  unstub docker
}

@test "Upload log settings: never" {
  export LOG_DIR="docker-compose-logs"

  run check_linked_containers_and_save_logs \
    "main" "/tmp/docker-compose-logs" "never"

  assert_success
}
