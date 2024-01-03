#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"
load '../lib/shared'
load '../lib/run'

# export BUILDKITE_AGENT_STUB_DEBUG=/dev/tty
# export DOCKER_COMPOSE_STUB_DEBUG=/dev/tty
# export DOCKER_STUB_DEBUG=/dev/tty
# export BATS_MOCK_TMPDIR=$PWD

setup_file() {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN_LABELS="false"
}

@test "Logs: Detect some containers KO" {
  export BUILDKITE_AGENT_ACCESS_TOKEN="123123"
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=""
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_COMMAND_0=echo
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_COMMAND_1="hello world"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=true
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false


  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 1" \
    "artifact upload docker-compose-logs/\*.log : exit 0"

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull myservice : echo built myservice" \
    "-f docker-compose.yml -p buildkite1111 up -d --scale myservice=0 myservice : echo ran myservice dependencies" \
    "-f docker-compose.yml -p buildkite1111 run --name buildkite1111_myservice_build_1 --rm myservice echo 'hello world' : echo ran myservice command"

  stub docker \
    "ps -a --filter label=com.docker.compose.project=buildkite1111 -q : cat tests/fixtures/id-multiple-services.txt" \
    "inspect -f {{if\ ne\ 0\ .State.ExitCode}}{{.Name}}.{{.State.ExitCode}}{{\ end\ }} 456456 789789 : echo 456456.1" \
    "ps -a --filter label=com.docker.compose.project=buildkite1111 --format \* : cat tests/fixtures/service-id-exit-multiple-services-failed.txt" \
    "ps -a --filter label=com.docker.compose.project=buildkite1111 --format \* : cat tests/fixtures/id-service-multiple-services.txt" \
    "inspect --format={{.State.ExitCode}} 456456 : echo 1" \
    "logs --timestamps --tail 5 456456 : exit 0" \
    "logs -t 456456 : exit 0" \
    "inspect --format={{.State.ExitCode}} 789789 : echo 0"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built myservice"
  assert_output --partial "ran myservice dependencies"
  assert_output --partial "ran myservice command"
  assert_output --partial "Some containers had non-zero exit codes"
  unstub buildkite-agent
  unstub docker-compose
  unstub docker
}

@test "Logs: Detect dependent services KO" {
  # Test for Issue #327, Container logs are not uploaded when services fail to start.
  export BUILDKITE_AGENT_ACCESS_TOKEN="123123"
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=""
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_COMMAND_0=echo
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_COMMAND_1="hello world"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=true
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false


  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 1" \
    "artifact upload docker-compose-logs/\*.log : exit 0"

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull myservice : echo built myservice" \
    "-f docker-compose.yml -p buildkite1111 up -d --scale myservice=0 myservice : exit 1" \

  stub docker \
    "ps -a --filter label=com.docker.compose.project=buildkite1111 -q : cat tests/fixtures/id-multiple-services.txt" \
    "inspect -f {{if\ ne\ 0\ .State.ExitCode}}{{.Name}}.{{.State.ExitCode}}{{\ end\ }} 456456 789789 : echo 456456.1" \
    "ps -a --filter label=com.docker.compose.project=buildkite1111 --format \* : cat tests/fixtures/service-id-exit-multiple-services-failed.txt" \
    "ps -a --filter label=com.docker.compose.project=buildkite1111 --format \* : cat tests/fixtures/id-service-multiple-services.txt" \
    "inspect --format={{.State.ExitCode}} 456456 : echo 1" \
    "logs --timestamps --tail 5 456456 : exit 0" \
    "logs -t 456456 : exit 0" \
    "inspect --format={{.State.ExitCode}} 789789 : echo 0"

  run "$PWD"/hooks/command

  assert_failure
  assert_output --partial "built myservice"
  assert_output --partial "Failed to start dependencies"
  assert_output --partial "Some containers had non-zero exit codes"
  unstub buildkite-agent
  unstub docker-compose
  unstub docker
}

@test "Logs: Detect all containers OK" {
  export BUILDKITE_AGENT_ACCESS_TOKEN="123123"
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=""
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_COMMAND_0=echo
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_COMMAND_1="hello world"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=true
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false


  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 1" \

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull myservice : echo built myservice" \
    "-f docker-compose.yml -p buildkite1111 up -d --scale myservice=0 myservice : echo ran myservice dependencies" \
    "-f docker-compose.yml -p buildkite1111 run --name buildkite1111_myservice_build_1 --rm myservice echo 'hello world' : echo ran myservice command"

  stub docker \
    "ps -a --filter label=com.docker.compose.project=buildkite1111 -q : cat tests/fixtures/id-multiple-services.txt" \
    "inspect -f {{if\ ne\ 0\ .State.ExitCode}}{{.Name}}.{{.State.ExitCode}}{{\ end\ }} 456456 789789 : echo" \
    "ps -a --filter label=com.docker.compose.project=buildkite1111 --format \* : cat tests/fixtures/id-service-multiple-services.txt" \
    "inspect --format={{.State.ExitCode}} 456456 : echo 0" \
    "inspect --format={{.State.ExitCode}} 789789 : echo 0"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built myservice"
  assert_output --partial "ran myservice dependencies"
  assert_output --partial "ran myservice command"
  refute_output --partial "Some containers had non-zero exit codes"
  unstub docker
  unstub docker-compose
  unstub buildkite-agent
}

@test "Logs: Skip output if there are no containers for a project" {
  # This covers the case when you have a single container being ran with `--rm` which
  # already outputs its logs to the console and given there are no other containers
  # we sohuld not try to get the logs or inspect them
  export BUILDKITE_AGENT_ACCESS_TOKEN="123123"
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=""
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_COMMAND_0=echo
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_COMMAND_1="hello world"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=true
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false


  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 1" \

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull myservice : echo built myservice" \
    "-f docker-compose.yml -p buildkite1111 up -d --scale myservice=0 myservice : echo ran myservice dependencies" \
    "-f docker-compose.yml -p buildkite1111 run --name buildkite1111_myservice_build_1 --rm myservice echo 'hello world' : echo ran myservice command"

  stub docker \
    "ps -a --filter label=com.docker.compose.project=buildkite1111 -q : echo" \
    "ps -a --filter label=com.docker.compose.project=buildkite1111 --format '{{.ID}}\\t{{.Label \"com.docker.compose.service\"}}' : cat tests/fixtures/id-service-no-services.txt"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built myservice"
  assert_output --partial "ran myservice dependencies"
  assert_output --partial "ran myservice command"
  refute_output --partial "Uploading linked container logs"
  unstub docker
  unstub docker-compose
  unstub buildkite-agent
}
