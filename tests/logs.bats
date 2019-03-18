#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'
load '../lib/run'
load '../lib/shared'

# export DOCKER_PS_BY_PROJECT_STUB_DEBUG=/dev/tty
# export CHECK_LINKED_CONTAINERS_AND_SAVE_LOGS_STUB_DEBUG=/dev/tty
# export DOCKER_STUB_DEBUG=/dev/tty

@test "Upload log settings: on-error" {
  export LOG_DIR="docker-compose-logs"

  function docker_ps_by_project() {
    echo -e "
232323\tmain
454545\tfailed
676767\tlinkedworked
898989\tlinkedworked2
"
  }

  function plugin_prompt_and_run() {
    echo "ran plugin_prompt_and_run"
  }

  stub docker \
    "inspect --format={{.State.ExitCode}} 454545 : echo 1" \
    "logs -t 454545 : echo got logs for failed" \
    "inspect --format={{.State.ExitCode}} 676767 : echo 0" \
    "inspect --format={{.State.ExitCode}} 898989 : echo 0"

  run check_linked_containers_and_save_logs \
    "main" "/tmp/docker-compose-logs" "on-error"

  assert_success
  assert_output --partial "ran plugin_prompt_and_run"

  unstub docker
}

@test "Upload log settings: always" {
  export LOG_DIR="docker-compose-logs"

  function docker_ps_by_project() {
    echo -e "
232323\tmain
454545\tfailed
676767\tlinkedworked
898989\tlinkedworked2
"
  }

  function plugin_prompt_and_run() {
    echo "ran plugin_prompt_and_run"
  }

  stub docker \
    "inspect --format={{.State.ExitCode}} 454545 : echo 1" \
    "logs -t 454545 : echo got logs for failed" \
    "inspect --format={{.State.ExitCode}} 676767 : echo 0" \
    "logs -t 676767 : echo got logs for failed" \
    "inspect --format={{.State.ExitCode}} 898989 : echo 0" \
    "logs -t 898989 : echo got logs for failed"

  run check_linked_containers_and_save_logs \
    "main" "/tmp/docker-compose-logs" "always"

  assert_success
  assert_output --partial "ran plugin_prompt_and_run"

  unstub docker
}

@test "Upload log settings: never" {
  export LOG_DIR="docker-compose-logs"

  function docker_ps_by_project() {
    echo -e "
232323\tmain
454545\tfailed
676767\tlinkedworked
898989\tlinkedworked2
"
  }

  function plugin_prompt_and_run() {
    echo "ran plugin_prompt_and_run"
  }

  run check_linked_containers_and_save_logs \
    "main" "/tmp/docker-compose-logs" "never"

  assert_success
}
