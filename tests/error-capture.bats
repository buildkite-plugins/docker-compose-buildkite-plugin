#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"
bats_require_minimum_version 1.5.0

setup() {
  source "$PWD/lib/shared.bash"
  export BUILDKITE_AGENT_JOB_API_CAPTURE_ERROR=true
  export -f record_capture
}

# Records every argument of a capture-error call.
function record_capture {
  [[ "$1" == job && "$2" == capture-error ]] || return 1
  local arg
  for arg in "${@:3}"; do
    jq -n --arg arg "$arg" '$arg'
  done | jq -sc '{args: .}' >>"$payload_file"
}

# Asserts that one error was captured with exactly this code and message, and
# no other arguments.
function assert_captured {
  local code="$1" message="$2"
  cat "$payload_file"
  [[ "$(wc -l <"$payload_file")" -eq 1 ]]
  jq -e --arg code "$code" --arg message "$message" \
    '.args == [$code, "--message", $message]' "$payload_file" >/dev/null
}

function configure_compose_hook {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN_LABELS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_COMMAND='echo hello world'
  export BUILDKITE_AGENT_JOB_API_SOCKET=/tmp/job.sock
  export BUILDKITE_AGENT_JOB_API_TOKEN=token
}

@test "successful Compose run emits no captured error" {
  configure_compose_hook
  marker="$BATS_TEST_TMPDIR/called"
  export marker
  function buildkite-agent() {
    [[ "$1" == job ]] && printf called >"$marker"
    return 1
  }
  export -f buildkite-agent
  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 up -d --scale myservice=0 myservice : echo dependencies started" \
    "compose -f docker-compose.yml -p buildkite1111 run --name buildkite1111_myservice_build_1 -T --rm myservice /bin/sh -e -c 'echo hello world' : echo command ran"

  run "$PWD/hooks/command"

  assert_success
  assert_output --partial "command ran"
  [[ ! -e "$marker" ]]
  unstub docker
}

@test "failed Compose run captures classification without changing status" {
  configure_compose_hook
  payload_file="$BATS_TEST_TMPDIR/payload"
  export payload_file
  function buildkite-agent() {
    if [[ "$1" == job ]]; then
      record_capture "$@"
      echo 'Unknown command: capture-error' >&2
      return 22
    fi
    return 1
  }
  export -f buildkite-agent
  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 up -d --scale myservice=0 myservice : echo dependencies started" \
    "compose -f docker-compose.yml -p buildkite1111 run --name buildkite1111_myservice_build_1 -T --rm myservice /bin/sh -e -c 'echo hello world' : echo command-stdout; echo process-failed >&2; exit 23"

  run "$PWD/hooks/command"

  assert_failure 23
  assert_captured compose_run_failed "Docker Compose run failed"
  [[ "$(grep -c '^process-failed$' <<<"$output")" -eq 1 ]]
  [[ "$(grep -c '^command-stdout$' <<<"$output")" -eq 1 ]]
  [[ "$output" != *'Unknown command'* ]]
  ! grep -q process-failed "$payload_file"
  unstub docker
}

@test "dependency failure inside Compose run does not claim a process ran" {
  configure_compose_hook
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PRE_RUN_DEPENDENCIES=false
  payload_file="$BATS_TEST_TMPDIR/payload"
  export payload_file
  function buildkite-agent() {
    if [[ "$1" == job ]]; then
      record_capture "$@"
      return 22
    fi
    return 1
  }
  export -f buildkite-agent
  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 run --name buildkite1111_myservice_build_1 -T --rm myservice /bin/sh -e -c 'echo hello world' : echo dependency-failed >&2; exit 18"

  run "$PWD/hooks/command"

  assert_failure 18
  assert_captured compose_run_failed "Docker Compose run failed"
  [[ "$(grep -c '^dependency-failed$' <<<"$output")" -eq 1 ]]
  unstub docker
}

@test "failed Compose build captures image failure without changing status" {
  configure_compose_hook
  unset BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  payload_file="$BATS_TEST_TMPDIR/payload"
  export payload_file
  function buildkite-agent() { record_capture "$@"; return 22; }
  export -f buildkite-agent
  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 build --pull myservice : echo build-stdout; printf 'build-progress\\n\\033[31mfailed to solve: exit code: 3\\033[0m\\n' >&2; exit 17"

  run "$PWD/hooks/command"

  assert_failure 17
  assert_captured image_build_failed "Failed to build services: failed to solve: exit code: 3"
  [[ "$(grep -c '^build-stdout$' <<<"$output")" -eq 1 ]]
  [[ "$(grep -c 'failed to solve' <<<"$output")" -eq 1 ]]
  unstub docker
}

@test "Compose build still runs when a temporary file can't be created" {
  configure_compose_hook
  unset BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export TMPDIR="$BATS_TEST_TMPDIR/missing"
  payload_file="$BATS_TEST_TMPDIR/payload"
  export payload_file
  function buildkite-agent() { record_capture "$@"; }
  export -f buildkite-agent
  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 build --pull myservice : echo build-failed >&2; exit 17"

  run "$PWD/hooks/command"

  assert_failure 17
  assert_captured image_build_failed "Failed to build services"
  [[ "$(grep -c '^build-failed$' <<<"$output")" -eq 1 ]]
  unstub docker
}

@test "Compose progress is not forced when stderr is copied" {
  export BUILDKITE_AGENT_JOB_API_SOCKET=/tmp/job.sock
  export BUILDKITE_AGENT_JOB_API_TOKEN=token
  export TERM=xterm
  function run_docker_compose() { echo "progress=${COMPOSE_PROGRESS:-unset}"; }

  run run_docker_compose_copying_stderr "$BATS_TEST_TMPDIR/stderr" build

  assert_success
  assert_output "progress=unset"
}

@test "Compose build message leaves out the command line and its build args" {
  configure_compose_hook
  unset BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_ARGS_0=REGISTRY_ARG=build-arg-value
  payload_file="$BATS_TEST_TMPDIR/payload"
  export payload_file
  function buildkite-agent() { record_capture "$@"; }
  export -f buildkite-agent
  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 build --pull --build-arg REGISTRY_ARG=build-arg-value myservice : echo build-stdout; exit 17"

  run "$PWD/hooks/command"

  assert_failure 17
  assert_output --partial "docker compose -f docker-compose.yml -p buildkite1111 build --pull --build-arg REGISTRY_ARG=build-arg-value myservice"
  # Compose writes no stderr, so a leaked command line would become the message.
  assert_captured image_build_failed "Failed to build services"
  ! grep -q build-arg-value "$payload_file"
  unstub docker
}

@test "failed dependency startup captures service failure without changing status" {
  configure_compose_hook
  payload_file="$BATS_TEST_TMPDIR/payload"
  export payload_file
  function buildkite-agent() {
    if [[ "$1" == job ]]; then
      record_capture "$@"
      return 22
    fi
    return 1
  }
  export -f buildkite-agent
  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 up -d --scale myservice=0 myservice : echo \"progress=\${COMPOSE_PROGRESS:-unset}\"; echo dependency-failed >&2; exit 18"

  run "$PWD/hooks/command"

  assert_failure 18
  assert_captured service_start_failed "Failed to start dependencies: dependency-failed"
  [[ "$(grep -c '^dependency-failed$' <<<"$output")" -eq 1 ]]
  # Compose's progress display isn't forced.
  assert_output --partial "progress=unset"
  unstub docker
}

@test "stderr error line is the last line without terminal codes or surrounding whitespace" {
  stderr_file="$BATS_TEST_TMPDIR/stderr"
  printf 'earlier line\r\n\033[1;33m \t Error: "quoted"  failure\033[0m \t\r\n\n\t\n  \n' >"$stderr_file"

  run stderr_error_line "$stderr_file"

  assert_success
  # Spaces inside the line are kept so redaction still matches secrets.
  assert_output 'Error: "quoted"  failure'
}

@test "stderr error line removes title and character set escape sequences" {
  stderr_file="$BATS_TEST_TMPDIR/stderr"
  printf '\033]0;title\007\033(BError\033]8;;https://example.invalid\033\\: denied\n' >"$stderr_file"

  run stderr_error_line "$stderr_file"

  assert_success
  assert_output 'Error: denied'
}

@test "captured message keeps a long error line for the agent to shorten" {
  export BUILDKITE_AGENT_JOB_API_SOCKET=/tmp/job.sock
  export BUILDKITE_AGENT_JOB_API_TOKEN=token
  payload_file="$BATS_TEST_TMPDIR/payload"
  export payload_file
  function buildkite-agent() { record_capture "$@"; }
  stderr_file="$BATS_TEST_TMPDIR/stderr"
  line="$(printf 'x%.0s' {1..1500})"
  printf 'earlier\n%s\n' "$line" >"$stderr_file"

  run capture_compose_error image_build_failed "Failed to build services" "$stderr_file"

  assert_success
  assert_captured image_build_failed "Failed to build services: $line"
}

@test "captured message leaves out an error line too large for the agent to accept" {
  export BUILDKITE_AGENT_JOB_API_SOCKET=/tmp/job.sock
  export BUILDKITE_AGENT_JOB_API_TOKEN=token
  payload_file="$BATS_TEST_TMPDIR/payload"
  export payload_file
  function buildkite-agent() { record_capture "$@"; }
  stderr_file="$BATS_TEST_TMPDIR/stderr"
  # 6,000 three-byte characters: under 16,000 characters, but over 16 KiB.
  printf '€%.0s' {1..6000} >"$stderr_file"

  run capture_compose_error image_build_failed "Failed to build services" "$stderr_file"

  assert_success
  assert_captured image_build_failed "Failed to build services"
}

@test "stderr error line removes colon-form colour codes and other control characters" {
  stderr_file="$BATS_TEST_TMPDIR/stderr"
  printf 'Error: sec\033[38:2::255:0:0mret\033[0m den\001ied\n' >"$stderr_file"

  run stderr_error_line "$stderr_file"

  assert_success
  assert_output 'Error: secret denied'
}

@test "stderr error line is empty for empty stderr" {
  stderr_file="$BATS_TEST_TMPDIR/stderr"
  : >"$stderr_file"

  run stderr_error_line "$stderr_file"

  assert_success
  assert_output ''
}

@test "run_copying_stderr preserves output streams and exit status without pipefail" {
  stderr_file="$BATS_TEST_TMPDIR/stderr"
  function noisy() { echo out; echo err >&2; return 7; }
  set +o pipefail

  run --separate-stderr run_copying_stderr "$stderr_file" noisy

  assert_failure 7
  [[ "$output" == out ]]
  [[ "$stderr" == err ]]
  [[ "$(cat "$stderr_file")" == err ]]
}

@test "capture reporting failure is ignored" {
  export BUILDKITE_AGENT_JOB_API_SOCKET=/tmp/job.sock
  export BUILDKITE_AGENT_JOB_API_TOKEN=token
  marker="$BATS_TEST_TMPDIR/called"
  export marker
  function buildkite-agent() { printf called >"$marker"; return 19; }

  run capture_compose_error service_start_failed diagnostic

  assert_success
  [[ "$(cat "$marker")" == "called" ]]
}

@test "capture sends only a code and a message" {
  export BUILDKITE_AGENT_JOB_API_SOCKET=/tmp/job.sock
  export BUILDKITE_AGENT_JOB_API_TOKEN=token
  payload_file="$BATS_TEST_TMPDIR/payload"
  export payload_file
  function buildkite-agent() { record_capture "$@"; }

  run capture_compose_error service_start_failed 'Failed to start dependencies'

  assert_success
  assert_captured service_start_failed 'Failed to start dependencies'
}

@test "capture is skipped unless the agent advertises support" {
  export BUILDKITE_AGENT_JOB_API_SOCKET=/tmp/job.sock
  export BUILDKITE_AGENT_JOB_API_TOKEN=token
  marker="$BATS_TEST_TMPDIR/called"
  function buildkite-agent() { printf called >"$marker"; }
  for capability in unset false; do
    export BUILDKITE_AGENT_JOB_API_CAPTURE_ERROR="$capability"
    if [[ "$capability" == unset ]]; then
      unset BUILDKITE_AGENT_JOB_API_CAPTURE_ERROR
    fi

    run capture_compose_error compose_run_failed diagnostic

    assert_success
    [[ ! -e "$marker" ]]
  done
}

@test "capture is skipped when the Local Job API is unavailable" {
  marker="$BATS_TEST_TMPDIR/called"
  function buildkite-agent() { printf called >"$marker"; return 99; }
  for missing in BUILDKITE_AGENT_JOB_API_SOCKET BUILDKITE_AGENT_JOB_API_TOKEN; do
    export BUILDKITE_AGENT_JOB_API_SOCKET=/tmp/job.sock
    export BUILDKITE_AGENT_JOB_API_TOKEN=token
    unset "$missing"

    run capture_compose_error compose_run_failed diagnostic

    assert_success
    [[ ! -e "$marker" ]]
  done
}

@test "stderr is not copied when error capture is unavailable" {
  unset BUILDKITE_AGENT_JOB_API_CAPTURE_ERROR

  run capture_stderr_file

  assert_success
  assert_output ''
}

@test "stderr is not copied when a temporary file can't be created" {
  export BUILDKITE_AGENT_JOB_API_SOCKET=/tmp/job.sock
  export BUILDKITE_AGENT_JOB_API_TOKEN=token
  export TMPDIR="$BATS_TEST_TMPDIR/missing"

  run capture_stderr_file

  assert_success
  assert_output ''
}

@test "run_copying_stderr runs the command normally without a file" {
  function noisy() { echo out; echo err >&2; return 7; }

  run --separate-stderr run_copying_stderr "" noisy

  assert_failure 7
  [[ "$output" == out ]]
  [[ "$stderr" == err ]]
}

@test "run_copying_stderr keeps the command's status when the copy can't be written" {
  function noisy() { echo err >&2; return 7; }
  function quiet() { echo err >&2; }

  run --separate-stderr run_copying_stderr "$BATS_TEST_TMPDIR/missing/stderr" noisy

  assert_failure 7
  [[ "$stderr" == *err* ]]

  run --separate-stderr run_copying_stderr "$BATS_TEST_TMPDIR/missing/stderr" quiet

  assert_success
}
