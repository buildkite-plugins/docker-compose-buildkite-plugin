#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"

setup() {
  source "$PWD/lib/shared.bash"
  export BUILDKITE_AGENT_JOB_API_CAPTURE_ERROR=true
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
      printf '%s' "$3" >"$payload_file"
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
  [[ "$(jq -r '.code' "$payload_file")" == "container_process_failed" ]]
  [[ "$(jq -r '.message' "$payload_file")" == "Failed to run service command" ]]
  [[ "$(grep -c '^process-failed$' <<<"$output")" -eq 1 ]]
  [[ "$(grep -c '^command-stdout$' <<<"$output")" -eq 1 ]]
  [[ "$output" != *'Unknown command'* ]]
  ! grep -q process-failed "$payload_file"
  unstub docker
}

@test "failed Compose build captures image failure without changing status" {
  configure_compose_hook
  unset BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  payload_file="$BATS_TEST_TMPDIR/payload"
  export payload_file
  function buildkite-agent() { printf '%s' "$3" >"$payload_file"; return 22; }
  export -f buildkite-agent
  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 build --pull myservice : echo build-failed >&2; exit 17"

  run "$PWD/hooks/command"

  assert_failure 17
  [[ "$(jq -r '.code' "$payload_file")" == "image_build_failed" ]]
  unstub docker
}

@test "failed dependency startup captures service failure without changing status" {
  configure_compose_hook
  payload_file="$BATS_TEST_TMPDIR/payload"
  export payload_file
  function buildkite-agent() {
    if [[ "$1" == job ]]; then
      printf '%s' "$3" >"$payload_file"
      return 22
    fi
    return 1
  }
  export -f buildkite-agent
  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 up -d --scale myservice=0 myservice : echo dependency-failed >&2; exit 18"

  run "$PWD/hooks/command"

  assert_failure 18
  [[ "$(jq -r '.code' "$payload_file")" == "service_start_failed" ]]
  unstub docker
}

@test "capture reporting failure is ignored" {
  export BUILDKITE_AGENT_JOB_API_SOCKET=/tmp/job.sock
  export BUILDKITE_AGENT_JOB_API_TOKEN=token
  marker="$BATS_TEST_TMPDIR/called"
  export marker
  function buildkite-agent() { printf called >"$marker"; return 19; }

  run capture_compose_error service_start_failed dependency_start 42 app diagnostic

  assert_success
  [[ "$(cat "$marker")" == "called" ]]
}

@test "capture sends structured context without command arguments" {
  export BUILDKITE_AGENT_JOB_API_SOCKET=/tmp/job.sock
  export BUILDKITE_AGENT_JOB_API_TOKEN=token
  payload_file="$BATS_TEST_TMPDIR/payload"
  export payload_file
  function buildkite-agent() { printf '%s' "$3" >"$payload_file"; }

  run capture_compose_error service_start_failed dependency_start 18 api 'service "db" failed'

  assert_success
  [[ "$(jq -r '.code' "$payload_file")" == "service_start_failed" ]]
  [[ "$(jq -r '.context.exit_status' "$payload_file")" == "18" ]]
  [[ "$(jq -r '.context.service' "$payload_file")" == "api" ]]
  [[ "$(jq -r '.message' "$payload_file")" == 'service "db" failed' ]]
  [[ "$(jq -r 'has("command") or (.context | has("command"))' "$payload_file")" == "false" ]]
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

    run capture_compose_error container_process_failed run 42 app diagnostic

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

    run capture_compose_error container_process_failed run 42 app diagnostic

    assert_success
    [[ ! -e "$marker" ]]
  done
}
